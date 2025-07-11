from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from werkzeug.security import generate_password_hash, check_password_hash
import razorpay
import hmac
import hashlib
import re
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///edu_delivery.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = 'jontheaegon'

RAZORPAY_KEY_ID = "rzp_test_FTDi97Hi0qWYoH"
RAZORPAY_KEY_SECRET = "sH1d9ewGnTKdTivFyV4k5dwZ"

db = SQLAlchemy(app)
jwt = JWTManager(app)
razorpay_client = razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))

def is_valid_email(email):
    return re.match(r"[^@]+@[^@]+\.[^@]+", email)

class Product(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    price = db.Column(db.Float, nullable=False)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(100), nullable=False, unique=True)
    email = db.Column(db.String(100), nullable=False, unique=True)
    password = db.Column(db.String(100), nullable=False)

    def set_password(self, password):
        self.password = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password, password)

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
    name = db.Column(db.String(100))        # New
    phone = db.Column(db.String(15))        # New
    address = db.Column(db.Text)            # New
    created_at = db.Column(db.DateTime, default=db.func.current_timestamp())


with app.app_context():
    db.create_all()

@app.route('/')
def home():
    return jsonify({"message": "Welcome to the app"})

@app.route('/add_sample_products')
def add_sample_products():
    sample_products = [Product(name="quantum physics", price=120),
                       Product(name="chemistry", price=120)]
    db.session.bulk_save_objects(sample_products)
    db.session.commit()
    return jsonify({"message": "sample products added"})

@app.route('/products', methods=['GET'])
def get_products():
    products = Product.query.all()
    product_list = [{"id": p.id, "name": p.name, "price": p.price} for p in products]
    return jsonify(product_list)

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(silent=True)
    if data is None:
        return jsonify({"error": "Invalid JSON format"}), 400

    username = data.get("username")
    email = data.get("email")
    password = data.get("password")

    if not username or not email or not password:
        return jsonify({"error": "All fields are mandatory"}), 400

    if not is_valid_email(email):
        return jsonify({"error": "Invalid email!"}), 400

    if User.query.filter_by(email=email).first():
        return jsonify({"error": "User already exists"}), 400

    new_user = User(username=username, email=email)
    new_user.set_password(password)
    db.session.add(new_user)
    db.session.commit()

    return jsonify({"message": "User registered successfully"}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True)
    email = data.get('email')
    password = data.get('password')

    user = User.query.filter_by(email=email).first()
    if not user or not user.check_password(password):
        return jsonify({"error": "Invalid E-mail or password"}), 401

    access_token = create_access_token(identity=str(user.id))
    return jsonify({"access_token": access_token})

@app.route('/profile', methods=['GET'])
@jwt_required()
def profile():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    return jsonify({"username": user.username, "email": user.email})

@app.route('/cart/add', methods=['POST'])
@jwt_required()
def add_to_cart():
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True)

    product_id = data.get("product_id")
    product_name = data.get("product_name")
    price = data.get("price")

    if product_id is None or product_name is None or price is None:
        return jsonify({"error": "Missing product details"}), 400

    cart_item = Cart.query.filter_by(user_id=user_id, product_id=product_id).first()
    if cart_item:
        cart_item.quantity += 1
    else:
        cart_item = Cart(
            user_id=user_id,
            product_id=product_id,
            product_name=product_name,
            price=price
        )
        db.session.add(cart_item)

    db.session.commit()
    return jsonify({"message": "Item added to cart"}), 201

@app.route('/cart', methods=['GET'])
@jwt_required()
def view_cart():
    user_id = int(get_jwt_identity())
    cart_items = Cart.query.filter_by(user_id=user_id).all()
    items = [{"id": item.id, "product_name": item.product_name, "price": item.price, "quantity": item.quantity} for item in cart_items]
    return jsonify({"cart": items})

@app.route('/cart/remove/<int:item_id>', methods=['DELETE'])
@jwt_required()
def remove_item_from_cart(item_id):
    user_id = int(get_jwt_identity())
    cart_item = Cart.query.filter_by(id=item_id, user_id=user_id).first()
    if not cart_item:
        return jsonify({"error": "Item not found in Cart!"}), 404

    db.session.delete(cart_item)
    db.session.commit()
    return jsonify({"message": "Item removed from cart"})

@app.route('/orders', methods=['GET'])
@jwt_required()
def view_orders():
    user_id = int(get_jwt_identity())
    orders = Order.query.filter_by(user_id=user_id).all()
    order_list = [{"id": order.id, "total_amount": order.total_amount, "status": order.status, "created_at": order.created_at.isoformat()} for order in orders]
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

@app.route('/search', methods=['GET'])
def search_products():
    query = request.args.get('q')
    if not query:
        return jsonify({"error": "Please provide a search item"}), 404

    products = Product.query.filter(Product.name.ilike(f"%{query}%")).all()
    product_list = [{"id": p.id, "name": p.name, "price": p.price} for p in products]
    return jsonify(product_list)

@app.route('/create_order', methods=['POST'])
@jwt_required()
def create_order():
    user_id = int(get_jwt_identity())
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

    # 🔒 Optional: Validate details
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

        # ✅ Place the order
        cart_items = Cart.query.filter_by(user_id=user_id).all()
        if not cart_items:
            return jsonify({"error": "Cart is empty"}), 400

        for item in cart_items:
            new_order = Order(
                user_id=user_id,
                product_id=item.product_id,
                quantity=item.quantity,
                total_amount=item.price * item.quantity,
                status="paid"
            )
            db.session.add(new_order)

        Cart.query.filter_by(user_id=user_id).delete()
        db.session.commit()

        return jsonify({"message": "Payment successful and order placed!"})

    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
