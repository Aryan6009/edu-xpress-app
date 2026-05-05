from app import db, Product, app

def populate():
    with app.app_context():
        # Clear existing products if any
        Product.query.delete()
        
        products = [
            Product(name="Python Crash Course", price=599.0, category="Coding", image="product_images/612n1tP4MOL.jpg"),
            Product(name="Deep Learning with Python", price=899.0, category="AI", image="product_images/71MHjHxMPVL._SL1000_.jpg"),
            Product(name="Fluent Python", price=750.0, category="Coding", image="product_images/81l3rZK4lnL._SY425_.jpg"),
            Product(name="Clean Code", price=450.0, category="Software Engineering", image=None),
            Product(name="The Pragmatic Programmer", price=550.0, category="Software Engineering", image=None),
            Product(name="Introduction to Algorithms", price=1200.0, category="Computer Science", image=None),
        ]
        
        db.session.bulk_save_objects(products)
        db.session.commit()
        print("Database populated successfully!")

if __name__ == "__main__":
    populate()
