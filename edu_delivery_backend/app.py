from flask import Flask, jsonify, request, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_bcrypt import Bcrypt
from flask_mail import Mail, Message
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_cors import CORS
from flask_admin import Admin
from flask_admin.form import ImageUploadField
from flask_admin.contrib.sqla import ModelView
from itsdangerous import URLSafeTimedSerializer, SignatureExpired
import razorpay
import hmac
import hashlib
import re
import os
import google.generativeai as genai

app = Flask(__name__)
app.config['SECRET_KEY'] = 'edu-xpress-admin-secret'
app.config['SECURITY_PASSWORD_SALT'] = 'edu-xpress-salt'

# --- Configuration ---
UPLOAD_FOLDER = 'uploads/product_images'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///edu_delivery.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = 'jontheaegon'

# Mail Configuration (Placeholders - Replace with real SMTP details)
app.config['MAIL_SERVER'] = 'smtp.gmail.com'
app.config['MAIL_PORT'] = 587
app.config['MAIL_USE_TLS'] = True
app.config['MAIL_USERNAME'] = 'aryan765208@gmail.com'
app.config['MAIL_PASSWORD'] = 'cyxo ndjb jhxu zchf'
app.config['MAIL_DEFAULT_SENDER'] = 'aryan765208@gmail.com'

# --- Initialize Extensions ---
db = SQLAlchemy(app)
bcrypt = Bcrypt(app)
jwt = JWTManager(app)
mail = Mail(app)
CORS(app)
admin = Admin(app, name='Edu-Xpress Admin')

# Rate Limiting
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["200 per day", "50 per hour"]
)

# Serializer for Email Verification Tokens
ts = URLSafeTimedSerializer(app.config["SECRET_KEY"])

# Razorpay
RAZORPAY_KEY_ID = "rzp_test_FTDi97Hi0qWYoH"
RAZORPAY_KEY_SECRET = "sH1d9ewGnTKdTivFyV4k5dwZ"
razorpay_client = razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))

# Gemini AI
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

# --- Helper Functions ---

def is_valid_email(email):
    return re.match(r"[^@]+@[^@]+\.[^@]+", email)

def check_password_strength(password):
    """
    Enforce: 8+ chars, 1 uppercase, 1 number, 1 special char.
    """
    if len(password) < 8:
        return False, "Password must be at least 8 characters long."
    if not re.search(r"[A-Z]", password):
        return False, "Password must contain at least one uppercase letter."
    if not re.search(r"\d", password):
        return False, "Password must contain at least one number."
    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        return False, "Password must contain at least one special character."
    return True, "Strong password."

def send_verification_email(email):
    token = ts.dumps(email, salt=app.config['SECURITY_PASSWORD_SALT'])
    verification_url = f"http://10.46.51.170:5000/verify-email/{token}" # Update with your IP/Domain
    
    msg = Message("Verify Your Email - Edu-Xpress", recipients=[email])
    msg.body = f"Welcome to Edu-Xpress! Please click the link to verify your email: {verification_url}\nThis link expires in 24 hours."
    
    try:
        mail.send(msg)
    except Exception as e:
        print(f"Failed to send email: {e}")

# --- Models ---

class Product(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    price = db.Column(db.Float, nullable=False)
    image = db.Column(db.String(200))
    category = db.Column(db.String(50), default="General")

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(100), nullable=False, unique=True)
    email = db.Column(db.String(100), nullable=False, unique=True)
    password = db.Column(db.String(100), nullable=False)
    is_verified = db.Column(db.Boolean, default=False) # New

    def set_password(self, password):
        self.password = bcrypt.generate_password_hash(password).decode('utf-8')

    def check_password(self, password):
        return bcrypt.check_password_hash(self.password, password)

class Cart(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('product.id'), nullable=False)
    product_name = db.Column(db.String(100), nullable=False)
    price = db.Column(db.Float, nullable=False)
    quantity = db.Column(db.Integer, default=1)

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
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())

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
        return jsonify({"error": "Verification link expired"}), 400
    except Exception:
        return jsonify({"error": "Invalid token"}), 400

    user = User.query.filter_by(email=email).first()
    if not user:
        return jsonify({"error": "User not found"}), 404

    user.is_verified = True
    db.session.commit()
    return jsonify({"message": "Email verified successfully! You can now login."}), 200

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
    return send_from_directory(os.path.join(os.getcwd(), 'uploads'), filename)

@app.route('/products', methods=['GET'])
def get_products():
    products = Product.query.order_by(Product.id.desc()).all()
    product_list = []
    for p in products:
        image_url = f"http://10.46.51.170:5000/uploads/product_images/{p.image}" if p.image else None
        product_list.append({
            "id": p.id,
            "name": p.name,
            "price": p.price,
            "category": p.category,
            "image": image_url
        })
    return jsonify(product_list)

@app.route('/profile', methods=['GET'])
@jwt_required()
def profile():
    user_id = get_jwt_identity()
    user = User.query.get(int(user_id))
    return jsonify({"username": user.username, "email": user.email})

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
        image_url = f"http://10.46.51.170:5000/uploads/product_images/{product.image}" if product and product.image else None
        items.append({
            "id": item.id,
            "product_id": item.product_id,
            "product_name": item.product_name,
            "price": item.price,
            "quantity": item.quantity,
            "image": image_url
        })
    return jsonify({"cart": items})

@app.route('/orders', methods=['GET'])
@jwt_required()
def view_orders():
    user_id = int(get_jwt_identity())
    orders = Order.query.filter_by(user_id=user_id).all()
    order_list = [{"id": o.id, "total_amount": o.total_amount, "status": o.status, "created_at": o.created_at.isoformat()} for o in orders]
    return jsonify({"orders": order_list})

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

    if not all([name, phone, address]):
        return jsonify({"error": "Missing delivery information"}), 400

    try:
        generated_signature = hmac.new(
            bytes(RAZORPAY_KEY_SECRET, 'utf-8'),
            bytes(razorpay_order_id + "|" + razorpay_payment_id, 'utf-8'),
            hashlib.sha256
        ).hexdigest()

        if generated_signature != razorpay_signature:
            return jsonify({"error": "Payment verification failed"}), 400

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
                address=address
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
    product_list = [{"id": p.id, "name": p.name, "price": p.price, "category": p.category, "image": f"http://10.46.51.170:5000/uploads/product_images/{p.image}" if p.image else None} for p in products]
    return jsonify(product_list)

@app.route('/chat', methods=['POST'])
def chat():
    data = request.get_json(silent=True)
    user_message = data.get("message", "").lower()
    if not user_message: return jsonify({"error": "Message required"}), 400
    if not GEMINI_API_KEY: return jsonify({"reply": "AI not configured."}), 500

    try:
        max_price = None
        price_match = re.search(r'(?:under|below|less than|within)\s*(?:rs\.?|₹)?\s*(\d+)', user_message)
        if price_match: max_price = float(price_match.group(1))

        query = Product.query
        if max_price: query = query.filter(Product.price <= max_price)
        
        keywords = ["coding", "python", "physics", "chemistry", "science", "fiction"]
        detected_keywords = [k for k in keywords if k in user_message]
        if detected_keywords:
            for kw in detected_keywords:
                query = query.filter((Product.name.ilike(f"%{kw}%")) | (Product.category.ilike(f"%{kw}%")))

        matching_products = query.limit(5).all()
        product_context = "\n".join([f"- {p.name} (₹{p.price})" for p in matching_products])

        model = genai.GenerativeModel('gemini-1.5-flash')
        system_prompt = f"You are Edu-Xpress AI. Help users shop books. Catalog:\n{product_context or 'No exact matches.'}\nMax 3 sentences."
        response = model.generate_content(f"{system_prompt}\nUser: {user_message}")
        return jsonify({"reply": response.text})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- Admin ---
class ProductAdmin(ModelView):
    column_list = ['name', 'price', 'category', 'image']
    form_extra_fields = {'image': ImageUploadField('Product Image', base_path=os.path.join(os.getcwd(), 'uploads/product_images'), relative_path='product_images/')}

admin.add_view(ModelView(User, db.session))
admin.add_view(ProductAdmin(Product, db.session))
admin.add_view(ModelView(Order, db.session))

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
