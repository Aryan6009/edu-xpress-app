class Product(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200))
    price = db.Column(db.Float)
    description = db.Column(db.String(500))
    image = db.Column(db.String(200))