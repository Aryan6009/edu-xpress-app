from flask import Flask, jsonify, request, send_from_directory, render_template, session, redirect, url_for, flash
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_bcrypt import Bcrypt
from flask_mail import Mail, Message
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_cors import CORS
from flask_admin import Admin, AdminIndexView, expose
from flask_admin.form import ImageUploadField
from flask_admin.contrib.sqla import ModelView
from flask_admin.theme import Bootstrap4Theme
from itsdangerous import URLSafeTimedSerializer, SignatureExpired
from dotenv import load_dotenv
import razorpay
import hmac
import hashlib
import re
import os
from openai import OpenAI

# Load environment variables
load_dotenv()

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'edu-xpress-default-secret')
app.config['SECURITY_PASSWORD_SALT'] = os.getenv('SECURITY_PASSWORD_SALT', 'edu-xpress-default-salt')

# --- Base URL Configuration ---
BASE_URL = os.getenv('BASE_URL', 'http://10.46.51.15:5000')

# --- Configuration ---
UPLOAD_FOLDER = 'uploads'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///edu_delivery_v2.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'jontheaegon')

# Mail Configuration
app.config['MAIL_SERVER'] = 'smtp.gmail.com'
app.config['MAIL_PORT'] = 587
app.config['MAIL_USE_TLS'] = True
app.config['MAIL_USERNAME'] = os.getenv('MAIL_USERNAME')
app.config['MAIL_PASSWORD'] = os.getenv('MAIL_PASSWORD')
app.config['MAIL_DEFAULT_SENDER'] = os.getenv('MAIL_DEFAULT_SENDER')

# --- Initialize Extensions ---
db = SQLAlchemy(app)
bcrypt = Bcrypt(app)
jwt = JWTManager(app)
mail = Mail(app)
CORS(app)

# Rate Limiting
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["1000 per day", "500 per hour"]
)

# Serializer for Email Verification Tokens
ts = URLSafeTimedSerializer(app.config["SECRET_KEY"])

# Razorpay
RAZORPAY_KEY_ID = os.getenv("RAZORPAY_KEY_ID")
RAZORPAY_KEY_SECRET = os.getenv("RAZORPAY_KEY_SECRET")
razorpay_client = razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))

# AI Configuration (NVIDIA or Grok)
NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY")
GROK_API_KEY = os.getenv("GROK_API_KEY")

ai_client = None
ai_model = "grok-beta" # Default model

if NVIDIA_API_KEY:
    ai_client = OpenAI(
        base_url="https://integrate.api.nvidia.com/v1",
        api_key=NVIDIA_API_KEY
    )
    ai_model = "meta/llama-3.2-3b-instruct" # User preferred model
elif GROK_API_KEY:
    ai_client = OpenAI(
        api_key=GROK_API_KEY,
        base_url="https://api.x.ai/v1",
    )
    ai_model = "grok-beta"

# --- Helper Functions ---

def is_valid_email(email):
    return re.match(r"[^@]+@[^@]+\.[^@]+", email)

def check_password_strength(password):
    if len(password) < 8:
        return False, "Password must be at least 8 characters long."
    if not re.search(r"\d", password):
        return False, "Password must contain at least one number."
    if not re.search(r"[A-Z]", password):
        return False, "Password must contain at least one uppercase letter."
    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        return False, "Password must contain at least one special character."
    return True, "Strong password."

def send_verification_email(email):
    try:
        token = ts.dumps(email, salt=app.config['SECURITY_PASSWORD_SALT'])
        # Use request.host_url to make the link dynamic based on how the API was accessed
        base = request.host_url.rstrip('/')
        verify_url = f"{base}/verify-email/{token}"
        
        msg = Message(
            "Verify Your Edu-Xpress Account",
            recipients=[email]
        )
        msg.body = f"Welcome to Edu-Xpress! Please verify your account by clicking the link below:\n\n{verify_url}\n\nThis link will expire in 24 hours."
        
        mail.send(msg)
        print(f"DEBUG: Verification email sent to {email} with link: {verify_url}")
        return True
    except Exception as e:
        print(f"ERROR sending email: {e}")
        return False

def get_image_url(image_path):
    if not image_path:
        return None
    if image_path.startswith('http'):
        return image_path
    
    # Try to use the current request host for a dynamic URL
    try:
        base = request.host_url.rstrip('/')
        return f"{base}/uploads/{image_path}"
    except Exception:
        # Fallback to hardcoded BASE_URL if called outside a request context
        return f"{BASE_URL}/uploads/{image_path}"

# --- Models ---

class Product(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    price = db.Column(db.Float, nullable=False)
    description = db.Column(db.Text, nullable=True) # Added description
    image = db.Column(db.String(200))
    category = db.Column(db.String(50), default="General")
    author = db.Column(db.String(100), nullable=True)
    isbn = db.Column(db.String(20), nullable=True)
    brand = db.Column(db.String(100), nullable=True) # For stationery
    specifications = db.Column(db.Text, nullable=True) # General specs

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(100), nullable=False, unique=True)
    email = db.Column(db.String(100), nullable=True, unique=True) # Email can be null for phone users
    password = db.Column(db.String(100), nullable=True) # Password can be null for social/phone users
    phone_number = db.Column(db.String(15), nullable=True, unique=True)
    google_id = db.Column(db.String(100), nullable=True, unique=True)
    is_verified = db.Column(db.Boolean, default=False)
    is_admin = db.Column(db.Boolean, default=False)

    def set_password(self, password):
        if password:
            self.password = bcrypt.generate_password_hash(password).decode('utf-8')

    def check_password(self, password):
        if self.password:
            return bcrypt.check_password_hash(self.password, password)
        return False

# Temporary storage for OTPs (In-memory, use Redis for production)
otp_storage = {}

# --- Auth Routes ---

from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")

@app.route('/google-login', methods=['POST'])
def google_login():
    data = request.get_json()
    token = data.get('id_token')

    if not token:
        return jsonify({"error": "No token provided"}), 400

    try:
        # Verify the token
        idinfo = id_token.verify_oauth2_token(token, google_requests.Request(), GOOGLE_CLIENT_ID)

        # ID token is valid. Get the user's Google ID from the decoded token.
        userid = idinfo['sub']
        email = idinfo.get('email')
        name = idinfo.get('name', 'Google User')

        # Check if user exists
        user = User.query.filter_by(google_id=userid).first()
        if not user:
            # Check if user with same email exists
            user = User.query.filter_by(email=email).first()
            if user:
                user.google_id = userid
            else:
                # Create new user
                user = User(
                    username=f"{name}_{userid[:5]}",
                    email=email,
                    google_id=userid,
                    is_verified=True
                )
                db.session.add(user)
            db.session.commit()

        access_token = create_access_token(identity=str(user.id))
        return jsonify({"access_token": access_token}), 200

    except ValueError:
        # Invalid token
        return jsonify({"error": "Invalid token"}), 400

@app.route('/send-otp', methods=['POST'])
def send_otp():
    data = request.get_json()
    phone = data.get('phone')

    if not phone:
        return jsonify({"error": "Phone number required"}), 400

    # Generate a 6-digit OTP
    import random
    otp = str(random.randint(100000, 999999))
    otp_storage[phone] = otp

    # In a real app, send SMS here. For now, print to console.
    print(f"--- OTP for {phone}: {otp} ---")

    return jsonify({"message": "OTP sent successfully"}), 200

@app.route('/mobile-login', methods=['POST'])
def mobile_login():
    data = request.get_json()
    phone = data.get('phone')
    otp = data.get('otp')

    if not phone or not otp:
        return jsonify({"error": "Phone and OTP required"}), 400

    if otp_storage.get(phone) == otp:
        # Success! Clear OTP
        del otp_storage[phone]

        # Check if user exists
        user = User.query.filter_by(phone_number=phone).first()
        if not user:
            # Create new user
            user = User(
                username=f"User_{phone[-4:]}",
                phone_number=phone,
                is_verified=True
            )
            db.session.add(user)
            db.session.commit()

        access_token = create_access_token(identity=str(user.id))
        return jsonify({"access_token": access_token}), 200
    else:
        return jsonify({"error": "Invalid OTP"}), 400

class Cart(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('product.id'), nullable=False)
    product_name = db.Column(db.String(100), nullable=False)
    price = db.Column(db.Float, nullable=False)
    quantity = db.Column(db.Integer, default=1)

class Address(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    full_address = db.Column(db.String(500), nullable=False)
    recipient_name = db.Column(db.String(100))
    recipient_phone = db.Column(db.String(15))
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    is_default = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())

class Order(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('product.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    total_amount = db.Column(db.Float, nullable=False)
    status = db.Column(db.String(100), default="pending")
    name = db.Column(db.String(100))
    phone = db.Column(db.String(15))
    address = db.Column(db.Text)
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())

class ChatHistory(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    message = db.Column(db.Text, nullable=False)
    reply = db.Column(db.Text, nullable=False)
    timestamp = db.Column(db.DateTime, default=db.func.current_timestamp())

with app.app_context():
    db.create_all()

# --- Auth Routes ---

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Invalid JSON"}), 400

    username = data.get("username")
    email = data.get("email")
    password = data.get("password")

    if not username or not email or not password:
        return jsonify({"error": "All fields are required"}), 400

    if not is_valid_email(email):
        return jsonify({"error": "Invalid email format"}), 400

    # Password Strength Validation
    is_strong, msg = check_password_strength(password)
    if not is_strong:
        return jsonify({"error": msg}), 400

    if User.query.filter_by(email=email).first():
        return jsonify({"error": "Email already registered"}), 400
    
    if User.query.filter_by(username=username).first():
        return jsonify({"error": "Username taken"}), 400

    new_user = User(username=username, email=email)
    new_user.set_password(password)
    db.session.add(new_user)
    db.session.commit()

    # Send Verification Email
    send_verification_email(email)

    return jsonify({"message": "Registration successful! Please check your email to verify your account."}), 201

@app.route('/verify-email/<token>')
def verify_email(token):
    try:
        email = ts.loads(token, salt=app.config['SECURITY_PASSWORD_SALT'], max_age=86400) # 24h
    except SignatureExpired:
        return '''
            <div style="text-align: center; margin-top: 50px; font-family: sans-serif;">
                <h1 style="color: #e74c3c;">Verification Link Expired</h1>
                <p>The verification link has expired. Please register again or request a new link.</p>
                <a href="/" style="color: #e67e22;">Back to Home</a>
            </div>
        ''', 400
    except Exception as e:
        print(f"DEBUG: Token Error: {e}")
        return '''
            <div style="text-align: center; margin-top: 50px; font-family: sans-serif;">
                <h1 style="color: #e74c3c;">Invalid Link</h1>
                <p>The verification link is invalid or broken.</p>
            </div>
        ''', 400

    user = User.query.filter_by(email=email).first()
    if not user:
        return '''
            <div style="text-align: center; margin-top: 50px; font-family: sans-serif;">
                <h1 style="color: #e74c3c;">User Not Found</h1>
                <p>We couldn't find a user associated with this email address.</p>
            </div>
        ''', 404

    if user.is_verified:
        return '''
            <div style="text-align: center; margin-top: 50px; font-family: sans-serif;">
                <h1 style="color: #27ae60;">Already Verified</h1>
                <p>Your email is already verified. You can now login to the app.</p>
            </div>
        '''

    user.is_verified = True
    db.session.commit()
    
    return '''
        <div style="text-align: center; margin-top: 50px; font-family: sans-serif;">
            <h1 style="color: #27ae60;">Email Verified!</h1>
            <p>Your account has been successfully verified. You can now login to the Edu-Xpress app.</p>
            <div style="margin-top: 20px; font-size: 50px;">📚✅</div>
        </div>
    '''

@app.route('/login', methods=['POST'])
@limiter.limit("5 per minute") # Rate limiting login attempts
def login():
    data = request.get_json(silent=True)
    email = data.get('email')
    password = data.get('password')

    user = User.query.filter_by(email=email).first()
    if not user or not user.check_password(password):
        return jsonify({"error": "Invalid email or password"}), 401

    if not user.is_verified:
        return jsonify({"error": "Please verify your email before logging in."}), 403

    access_token = create_access_token(identity=str(user.id))
    return jsonify({"access_token": access_token}), 200

# --- App Routes ---

@app.route('/')
def home():
    return jsonify({"message": "Welcome to Edu-Xpress API"})

@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    """
    Serve uploaded files with robust path detection and detailed logging.
    """
    # Possible base directories for uploads
    base_path = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(base_path)
    
    possible_dirs = [
        os.path.join(project_root, 'uploads'),
        os.path.join(base_path, 'uploads'),
        os.path.join(os.getcwd(), 'uploads'),
        os.path.join(os.getcwd(), 'edu_delivery_backend', 'uploads')
    ]
    
    for uploads_dir in possible_dirs:
        # Normalize and join paths
        target_path = os.path.normpath(os.path.join(uploads_dir, filename))
        
        # Security check: ensure the target is within the uploads_dir
        if not target_path.startswith(os.path.normpath(uploads_dir)):
            continue
            
        if os.path.exists(target_path) and os.path.isfile(target_path):
            print(f"DEBUG: Found {filename} at {target_path}")
            # Use the directory part of the target path for send_from_directory
            return send_from_directory(os.path.dirname(target_path), os.path.basename(target_path))
    
    print(f"DEBUG: File {filename} NOT FOUND. Checked: {possible_dirs}")
    return jsonify({"error": f"File {filename} not found"}), 404

@app.route('/products', methods=['GET'])
def get_products():
    products = Product.query.order_by(Product.id.desc()).all()
    product_list = []
    for p in products:
        product_list.append({
            "id": p.id,
            "name": p.name,
            "price": p.price,
            "description": p.description,
            "category": p.category,
            "image": get_image_url(p.image),
            "author": p.author,
            "isbn": p.isbn,
            "brand": p.brand,
            "specifications": p.specifications
        })
    return jsonify(product_list)

@app.route('/profile', methods=['GET', 'PUT'])
@jwt_required()
def profile():
    user_id = get_jwt_identity()
    user = User.query.get(int(user_id))
    
    if request.method == 'PUT':
        data = request.get_json()
        new_username = data.get('username')
        new_email = data.get('email')
        
        if new_username:
            if User.query.filter(User.username == new_username, User.id != user.id).first():
                return jsonify({"error": "Username already taken"}), 409
            user.username = new_username
            
        if new_email:
            if not is_valid_email(new_email):
                return jsonify({"error": "Invalid email format"}), 400
            if User.query.filter(User.email == new_email, User.id != user.id).first():
                return jsonify({"error": "Email already registered"}), 409
            user.email = new_email
            
        db.session.commit()
        return jsonify({"message": "Profile updated successfully"})
        
    return jsonify({"username": user.username, "email": user.email})

@app.route('/save-address', methods=['POST'])
@jwt_required()
def save_address():
    user_id = int(get_jwt_identity())
    data = request.get_json()
    
    full_address = data.get("address")
    recipient_name = data.get("recipient_name")
    recipient_phone = data.get("recipient_phone")
    lat = data.get("latitude")
    lng = data.get("longitude")
    is_default = data.get("is_default", False)
    
    if not all([full_address, lat, lng]):
        return jsonify({"error": "Missing address details"}), 400

    if is_default:
        Address.query.filter_by(user_id=user_id).update({"is_default": False})
        
    new_address = Address(
        user_id=user_id,
        full_address=full_address,
        recipient_name=recipient_name,
        recipient_phone=recipient_phone,
        latitude=lat,
        longitude=lng,
        is_default=is_default
    )
    db.session.add(new_address)
    db.session.commit()
    return jsonify({"message": "Address saved successfully"}), 201

@app.route('/addresses', methods=['GET'])
@jwt_required()
def get_addresses():
    user_id = int(get_jwt_identity())
    addresses = Address.query.filter_by(user_id=user_id).all()
    return jsonify([{
        "id": a.id,
        "address": a.full_address,
        "recipient_name": a.recipient_name,
        "recipient_phone": a.recipient_phone,
        "latitude": a.latitude,
        "longitude": a.longitude,
        "is_default": a.is_default
    } for a in addresses])

@app.route('/set-default-address/<int:address_id>', methods=['PUT'])
@jwt_required()
def set_default_address(address_id):
    user_id = int(get_jwt_identity())
    Address.query.filter_by(user_id=user_id).update({"is_default": False})
    
    address = Address.query.filter_by(id=address_id, user_id=user_id).first()
    if not address:
        return jsonify({"error": "Address not found"}), 404
        
    address.is_default = True
    db.session.commit()
    return jsonify({"message": "Default address updated"})

@app.route('/delete-address/<int:address_id>', methods=['DELETE'])
@jwt_required()
def delete_address(address_id):
    user_id = int(get_jwt_identity())
    address = Address.query.filter_by(id=address_id, user_id=user_id).first()
    if not address:
        return jsonify({"error": "Address not found"}), 404
        
    db.session.delete(address)
    db.session.commit()
    return jsonify({"message": "Address deleted successfully"}), 200

@app.route('/cart/add', methods=['POST'])
@jwt_required()
def add_to_cart():
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True)
    product_id = data.get("product_id")
    
    # Try to get existing cart item
    cart_item = Cart.query.filter_by(user_id=user_id, product_id=product_id).first()
    
    if cart_item:
        cart_item.quantity += 1
        db.session.commit()
        return jsonify({"message": "Quantity increased"}), 201
    
    # If not in cart, we need product details to add it
    product_name = data.get("product_name")
    price = data.get("price")
    
    # Fallback: Look up from Product table if name/price missing
    if not product_name or price is None:
        product = Product.query.get(product_id)
        if product:
            product_name = product.name
            price = product.price
    
    if product_id is None or product_name is None or price is None:
        return jsonify({"error": "Missing product details"}), 400

    cart_item = Cart(user_id=user_id, product_id=product_id, product_name=product_name, price=price)
    db.session.add(cart_item)
    db.session.commit()
    return jsonify({"message": "Item added to cart"}), 201

@app.route('/cart/decrease/<product_id>', methods=['POST'])
@app.route('/cart/decrease/<int:product_id>', methods=['POST'])
@jwt_required()
def decrease_cart_item(product_id):
    try:
        user_id = int(get_jwt_identity())
        # Ensure product_id is an integer
        p_id = int(product_id)
        
        print(f"DEBUG: Processing decrease for User:{user_id}, Product:{p_id}")
        
        cart_item = Cart.query.filter_by(user_id=user_id, product_id=p_id).first()
        
        if not cart_item:
            print(f"DEBUG: Item {p_id} NOT found in cart for User:{user_id}")
            return jsonify({"error": "Item not in cart"}), 409 # Using 409 to distinguish from 404 routing error

        if cart_item.quantity > 1:
            cart_item.quantity -= 1
            print(f"DEBUG: Quantity reduced to {cart_item.quantity}")
        else:
            db.session.delete(cart_item)
            print(f"DEBUG: Item removed from cart")
        
        db.session.commit()
        return jsonify({"message": "Success"}), 200
        
    except Exception as e:
        print(f"CRITICAL ERROR in decrease_cart_item: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/debug/cart', methods=['GET'])
def debug_cart():
    items = Cart.query.all()
    return jsonify([{
        "id": i.id,
        "user_id": i.user_id,
        "product_id": i.product_id,
        "qty": i.quantity
    } for i in items])

@app.route('/cart/remove/<int:product_id>', methods=['DELETE'])
@jwt_required()
def remove_item_from_cart(product_id):
    user_id = int(get_jwt_identity())
    cart_item = Cart.query.filter_by(user_id=user_id, product_id=product_id).first()
    if not cart_item:
        return jsonify({"error": "Item not found"}), 404

    db.session.delete(cart_item)
    db.session.commit()
    return jsonify({"message": "Item removed from cart"}), 200

@app.route('/cart', methods=['GET'])
@jwt_required()
def view_cart():
    user_id = int(get_jwt_identity())
    cart_items = Cart.query.filter_by(user_id=user_id).all()
    items = []
    for item in cart_items:
        product = Product.query.get(item.product_id)
        items.append({
            "id": item.id,
            "product_id": item.product_id,
            "product_name": item.product_name,
            "price": item.price,
            "quantity": item.quantity,
            "image": get_image_url(product.image) if product else None
        })
    return jsonify({"cart": items})

@app.route('/orders', methods=['GET'])
@jwt_required()
def view_orders():
    user_id = int(get_jwt_identity())
    # Join with Product to get name and image
    results = db.session.query(Order, Product).join(Product, Order.product_id == Product.id).filter(Order.user_id == user_id).order_by(Order.created_at.desc()).all()
    
    order_list = []
    for o, p in results:
        order_list.append({
            "id": o.id,
            "product_id": o.product_id,
            "product_name": p.name,
            "product_image": get_image_url(p.image),
            "quantity": o.quantity,
            "total_amount": o.total_amount,
            "status": o.status,
            "address": o.address,
            "created_at": o.created_at.isoformat()
        })
    return jsonify({"orders": order_list})

@app.route('/order/<int:order_id>', methods=['GET'])
@jwt_required()
def view_order_details(order_id):
    user_id = int(get_jwt_identity())
    result = db.session.query(Order, Product).join(Product, Order.product_id == Product.id).filter(Order.id == order_id, Order.user_id == user_id).first()
    
    if not result:
        return jsonify({"error": "Order not found"}), 404
        
    o, p = result
    return jsonify({
        "id": o.id,
        "product_id": o.product_id,
        "product_name": p.name,
        "product_image": get_image_url(p.image),
        "quantity": o.quantity,
        "total_amount": o.total_amount,
        "status": o.status,
        "name": o.name,
        "phone": o.phone,
        "address": o.address,
        "latitude": o.latitude,
        "longitude": o.longitude,
        "created_at": o.created_at.isoformat()
    })

@app.route('/order/<int:order_id>/status', methods=['PUT'])
@jwt_required()
def update_order_status(order_id):
    user_id = int(get_jwt_identity())
    data = request.get_json()
    new_status = data.get('status')
    
    if not new_status:
        return jsonify({"error": "Status required"}), 400
        
    order = Order.query.filter_by(id=order_id, user_id=user_id).first()
    if not order:
        return jsonify({"error": "Order not found"}), 404
        
    order.status = new_status
    db.session.commit()
    return jsonify({"message": f"Order status updated to {new_status}"})

@app.route('/cancel_order/<int:order_id>', methods=['DELETE'])
@jwt_required()
def cancel_order(order_id):
    user_id = int(get_jwt_identity())
    order = Order.query.filter_by(id=order_id, user_id=user_id).first()
    if not order:
        return jsonify({"error": "Order not found!"}), 404

    db.session.delete(order)
    db.session.commit()
    return jsonify({"message": "Order cancelled successfully"})

@app.route('/create_order', methods=['POST'])
@jwt_required()
def create_order():
    data = request.get_json(silent=True)
    try:
        amount = float(data.get('amount'))
        if amount <= 0:
            return jsonify({"error": "Amount must be greater than 0"}), 400
    except (TypeError, ValueError):
        return jsonify({"error": "Invalid amount"}), 400

    try:
        razorpay_order = razorpay_client.order.create({
            "amount": int(amount * 100),
            "currency": "INR",
            "payment_capture": 1
        })
        return jsonify({
            "order_id": razorpay_order["id"],
            "amount": int(amount * 100),
            "currency": "INR"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/verify_payment', methods=['POST'])
@jwt_required()
def verify_payment():
    data = request.get_json()
    user_id = int(get_jwt_identity())
    razorpay_order_id = data.get('razorpay_order_id')
    razorpay_payment_id = data.get('razorpay_payment_id')
    razorpay_signature = data.get('razorpay_signature')
    name = data.get('name')
    phone = data.get('phone')
    address = data.get('address')
    latitude = data.get('latitude')
    longitude = data.get('longitude')

    # Debug logging
    print(f"DEBUG: Received verification request for Order: {razorpay_order_id}")
    print(f"DEBUG: Data: name={name}, phone={phone}, lat={latitude}, lng={longitude}")

    if not all([name, phone, address]):
        return jsonify({"error": f"Missing delivery info. Got: name={name}, phone={phone}, address={address}"}), 400

    try:
        # Official Razorpay verification
        verification_data = {
            'razorpay_order_id': razorpay_order_id,
            'razorpay_payment_id': razorpay_payment_id,
            'razorpay_signature': razorpay_signature
        }
        
        try:
            razorpay_client.utility.verify_payment_signature(verification_data)
        except Exception as e:
            print(f"VERIFICATION FAILED for {razorpay_order_id}: {str(e)}")
            return jsonify({"error": f"Signature mismatch or invalid: {str(e)}"}), 400

        cart_items = Cart.query.filter_by(user_id=user_id).all()
        if not cart_items:
            return jsonify({"error": "Cart is empty"}), 400

        for item in cart_items:
            new_order = Order(
                user_id=user_id,
                product_id=item.product_id,
                quantity=item.quantity,
                total_amount=item.price * item.quantity,
                status="paid",
                name=name,
                phone=phone,
                address=address,
                latitude=latitude,
                longitude=longitude
            )
            db.session.add(new_order)

        Cart.query.filter_by(user_id=user_id).delete()
        db.session.commit()
        return jsonify({"message": "Payment successful and order placed!"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/search', methods=['GET'])
def search_products():
    query = request.args.get('q')
    if not query:
        return jsonify({"error": "Search query required"}), 400
    products = Product.query.filter(Product.name.ilike(f"%{query}%")).all()
    product_list = [{
        "id": p.id, 
        "name": p.name, 
        "price": p.price, 
        "description": p.description,
        "category": p.category, 
        "image": get_image_url(p.image),
        "author": p.author,
        "isbn": p.isbn,
        "brand": p.brand,
        "specifications": p.specifications
    } for p in products]
    return jsonify(product_list)
def get_search_params(message):
    """
    Use AI to determine if the user is searching for products and extract search terms.
    """
    if not ai_client:
        return None
        
    prompt = (
        f"Analyze this user message for a book store app: '{message}'\n"
        f"Determine if they are looking for books or products from our catalog.\n"
        f"Return ONLY a JSON object with these keys: "
        f"'is_search' (boolean), 'query' (string for database search or null), 'max_price' (number or null).\n"
        f"Rules:\n"
        f"- is_search should be true if they want to see, find, or get suggestions for books.\n"
        f"- query should be a simple search term like 'Python' or 'Physics'.\n"
        f"- max_price should be a number if they mentioned a budget.\n"
    )
    
    try:
        response = ai_client.chat.completions.create(
            model=ai_model,
            messages=[{"role": "user", "content": prompt}],
            response_format={ "type": "json_object" } if "grok" in ai_model else None
        )
        content = response.choices[0].message.content
        import json
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            content = content.split("```")[1].split("```")[0].strip()
        return json.loads(content)
    except Exception as e:
        print(f"AI Search Intent Error: {e}")
        return None

@app.route('/chat', methods=['POST'])
@jwt_required(optional=True)
def chat():
    data = request.get_json(silent=True)
    user_message = data.get("message", "").lower()
    if not user_message: return jsonify({"error": "Message required"}), 400
    if not ai_client: return jsonify({"reply": "AI not configured (Missing API Key)."}), 500

    user_id = get_jwt_identity()
    
    # Context for AI
    order_context = ""
    history_messages = []
    
    if user_id:
        user_id_int = int(user_id)
        # Fetch last 5 orders for better context
        last_orders = Order.query.filter_by(user_id=user_id_int).order_by(Order.created_at.desc()).limit(5).all()
        if last_orders:
            order_info = []
            for o in last_orders:
                p = Product.query.get(o.product_id)
                p_name = p.name if p else "Unknown Book"
                order_info.append(f"Order #ORD{o.id}: {p_name}, Total: ₹{o.total_amount}, Status: {o.status}")
            order_context = "User's Recent Orders:\n" + "\n".join(order_info)
        
        # NEW: Fetch last 10 chat messages for memory
        history = ChatHistory.query.filter_by(user_id=user_id_int).order_by(ChatHistory.timestamp.asc()).limit(10).all()
        for h in history:
            history_messages.append({"role": "user", "content": h.message})
            history_messages.append({"role": "assistant", "content": h.reply})

    try:
        # Check for Cancellation Intent
        cancel_match = re.search(r'(?:cancel|terminate|stop)\s+(?:my\s+)?(?:order\s+)?(?:#?ord)?(\d+)', user_message)
        if cancel_match:
            order_id = int(cancel_match.group(1))
            order = Order.query.filter_by(id=order_id, user_id=int(user_id)).first() if user_id else None
            
            if order:
                if order.status.lower() in ['delivered', 'cancelled']:
                    return jsonify({"reply": f"Order #ORD{order_id} is already {order.status}."})
                
                order.status = "cancelled"
                db.session.commit()
                return jsonify({
                    "reply": f"Your order #ORD{order_id} has been successfully cancelled.",
                    "action": "order_cancelled",
                    "order_id": order_id
                })
            elif user_id:
                return jsonify({"reply": f"I couldn't find an order with ID #ORD{order_id}."})
            else:
                return jsonify({"reply": "Please login to cancel your order."})

        # --- Product Recommendation Logic using AI Intent ---
        search_params = get_search_params(user_message)
        
        should_search_products = False
        search_query = None
        max_price = None
        
        if search_params:
            should_search_products = search_params.get('is_search', False)
            search_query = search_params.get('query')
            max_price = search_params.get('max_price')

        products_data = []
        product_context = ""

        if should_search_products:
            query = Product.query
            if max_price: 
                query = query.filter(Product.price <= max_price)
            
            if search_query:
                query = query.filter((Product.name.ilike(f"%{search_query}%")) | (Product.category.ilike(f"%{search_query}%")) | (Product.description.ilike(f"%{search_query}%")))

            matching_products = query.limit(5).all()
            
            for p in matching_products:
                products_data.append({
                    "id": p.id,
                    "name": p.name,
                    "price": p.price,
                    "category": p.category,
                    "image": get_image_url(p.image)
                })
            
            if matching_products:
                product_context = "Available books matching query:\n" + "\n".join([f"- {p.name} (₹{p.price})" for p in matching_products])
            else:
                product_context = "No books matching the specific criteria were found in our catalog, but you can suggest others."

        system_prompt = (
            f"You are Edu-Xpress AI, a helpful book store assistant.\n"
            f"{product_context}\n\n"
            f"{order_context or 'No recent orders found.'}\n\n"
            f"Instructions:\n"
            f"1. Be helpful and very concise (max 2 sentences).\n"
            f"2. ONLY mention specific books if they are in the 'Available books' list provided above.\n"
            f"3. If the user wants to buy or add a book, encourage them to use the 'Add' button on the product cards shown.\n"
            f"4. If the user is just saying hello or chatting generally, do NOT list books unless asked.\n"
            f"5. If not logged in and asking about orders, ask them to log in."
        )
        
        messages = [{"role": "system", "content": system_prompt}]
        messages.extend(history_messages)
        messages.append({"role": "user", "content": user_message})

        completion = ai_client.chat.completions.create(
            model=ai_model,
            messages=messages
        )
        
        reply = completion.choices[0].message.content
        
        # NEW: Save to history
        if user_id:
            new_chat = ChatHistory(user_id=int(user_id), message=user_message, reply=reply)
            db.session.add(new_chat)
            db.session.commit()
            
        return jsonify({
            "reply": reply,
            "products": products_data
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/chat/history', methods=['GET'])
@jwt_required()
def get_chat_history():
    user_id = int(get_jwt_identity())
    history = ChatHistory.query.filter_by(user_id=user_id).order_by(ChatHistory.timestamp.asc()).limit(20).all()
    return jsonify([{
        "message": h.message,
        "reply": h.reply,
        "timestamp": h.timestamp.isoformat() if h.timestamp else None,
        "isUser": False
    } for h in history])


def extract_product_metadata(name, description, category):
    """
    Use AI to extract structured metadata from product name and description.
    """
    if not ai_client:
        return None
        
    prompt = (
        f"Extract structured metadata for this product:\n"
        f"Name: {name}\n"
        f"Description: {description}\n"
        f"Category: {category}\n\n"
        f"Return ONLY a JSON object with these keys: "
        f"'author', 'isbn', 'brand', 'specifications'.\n"
        f"Rules:\n"
        f"- For books, find author and ISBN.\n"
        f"- For stationery/other, find brand and dimensions/specs.\n"
        f"- Use null if not found. No extra text."
    )
    
    try:
        response = ai_client.chat.completions.create(
            model=ai_model,
            messages=[{"role": "user", "content": prompt}],
            response_format={ "type": "json_object" } if "grok" in ai_model else None
        )
        content = response.choices[0].message.content
        import json
        # Clean potential markdown code blocks
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            content = content.split("```")[1].split("```")[0].strip()
            
        return json.loads(content)
    except Exception as e:
        print(f"AI Metadata Extraction Error: {e}")
        return None


# --- Secure Admin ---
class SecureModelView(ModelView):
    def is_accessible(self):
        return session.get('admin_logged_in') == True

    def inaccessible_callback(self, name, **kwargs):
        return redirect(url_for('admin_login', next=request.url))

class MyAdminIndexView(AdminIndexView):
    @expose('/')
    def index(self):
        if not session.get('admin_logged_in'):
            return redirect(url_for('admin_login', next=request.url))
            
        from sqlalchemy import func
        user_count = User.query.count()
        product_count = Product.query.count()
        order_count = Order.query.count()
        total_revenue = db.session.query(func.sum(Order.total_amount)).scalar() or 0
        
        return self.render('admin/dashboard.html', 
                           user_count=user_count,
                           product_count=product_count,
                           order_count=order_count,
                           total_revenue=total_revenue)

@app.route('/admin-login', methods=['GET', 'POST'])
def admin_login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        user = User.query.filter((User.email == username) | (User.username == username)).first()
        
        if user and user.is_admin and user.check_password(password):
            session['admin_logged_in'] = True
            session['admin_user'] = user.username
            return redirect(url_for('admin.index'))
        else:
            flash('Invalid admin credentials')
            
    return render_template('admin_login.html')

@app.route('/admin-logout')
def admin_logout():
    session.pop('admin_logged_in', None)
    session.pop('admin_user', None)
    return redirect(url_for('admin_login'))

# --- Admin ---
class ProductAdmin(SecureModelView):
    column_list = ['name', 'price', 'category', 'author', 'isbn', 'brand']
    form_columns = ['name', 'price', 'description', 'category', 'author', 'isbn', 'brand', 'specifications', 'image']
    
    def on_model_change(self, form, model, is_created):
        """
        Triggered when a product is saved in admin.
        Automatically fill metadata if missing.
        """
        if model.description and (not model.author and not model.isbn and not model.brand):
            print(f"DEBUG: Triggering AI metadata extraction for {model.name}")
            meta = extract_product_metadata(model.name, model.description, model.category)
            if meta:
                model.author = meta.get('author') or model.author
                model.isbn = meta.get('isbn') or model.isbn
                model.brand = meta.get('brand') or model.brand
                model.specifications = meta.get('specifications') or model.specifications

    # Pre-defined categories
    form_choices = {
        'category': [
            ('Kids', 'Kids'),
            ('Learning', 'Learning'),
            ('Competitive Exams', 'Competitive Exams'),
            ('School', 'School'),
            ('Stationery', 'Stationery'),
            ('College', 'College'),
            ('General', 'General')
        ]
    }
    
    form_extra_fields = {
        'image': ImageUploadField(
            'Product Image', 
            base_path=os.path.join(os.getcwd(), 'uploads'), 
            relative_path='product_images/'
        )
    }

admin = Admin(app, name='Edu-Xpress Admin', theme=Bootstrap4Theme(), index_view=MyAdminIndexView())
admin.add_view(SecureModelView(User, db.session))
admin.add_view(ProductAdmin(Product, db.session))
admin.add_view(SecureModelView(Order, db.session))

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
