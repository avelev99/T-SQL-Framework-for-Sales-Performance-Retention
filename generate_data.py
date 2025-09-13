import pandas as pd
import numpy as np
import os
import random
import datetime

# Set random seed for reproducibility
np.random.seed(42)
random.seed(42)

# Directory to store synthetic data
DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
os.makedirs(DATA_DIR, exist_ok=True)

# Configuration for number of records
N_CUSTOMERS = 200
N_SELLERS = 50
N_PRODUCTS = 100
N_ORDERS = 1000

def gen_id(length: int = 32) -> str:
    """Generate a random hexadecimal string of the specified length."""
    return ''.join(random.choices('0123456789abcdef', k=length))


def generate_customers() -> pd.DataFrame:
    """Create a synthetic customers table."""
    customer_ids = [gen_id(32) for _ in range(N_CUSTOMERS)]
    customer_unique_ids = [gen_id(32) for _ in range(N_CUSTOMERS)]
    zip_prefixes = np.random.randint(10000, 99999, N_CUSTOMERS).astype(str)
    cities = np.random.choice(
        [
            "Sofia",
            "Plovdiv",
            "Varna",
            "Burgas",
            "Ruse",
            "Stara Zagora",
            "Pleven",
            "Sliven",
            "Dobrich",
            "Shumen",
        ],
        N_CUSTOMERS,
    )
    states = ["BG"] * N_CUSTOMERS
    return pd.DataFrame(
        {
            "customer_id": customer_ids,
            "customer_unique_id": customer_unique_ids,
            "customer_zip_code_prefix": zip_prefixes,
            "customer_city": cities,
            "customer_state": states,
        }
    )


def generate_sellers() -> pd.DataFrame:
    """Create a synthetic sellers table."""
    seller_ids = [gen_id(32) for _ in range(N_SELLERS)]
    zip_codes = np.random.randint(10000, 99999, N_SELLERS).astype(str)
    cities = np.random.choice(
        [
            "Sofia",
            "Plovdiv",
            "Varna",
            "Burgas",
            "Ruse",
            "Stara Zagora",
            "Pleven",
            "Sliven",
            "Dobrich",
            "Shumen",
        ],
        N_SELLERS,
    )
    states = ["BG"] * N_SELLERS
    return pd.DataFrame(
        {
            "seller_id": seller_ids,
            "seller_zip_code_prefix": zip_codes,
            "seller_city": cities,
            "seller_state": states,
        }
    )


def generate_products() -> pd.DataFrame:
    """Create a synthetic products table."""
    categories = [
        "bed_bath_table",
        "health_beauty",
        "computers",
        "books",
        "toys",
        "sports",
        "groceries",
        "pet_shop",
        "auto",
        "furniture",
    ]
    product_ids = [gen_id(32) for _ in range(N_PRODUCTS)]
    product_categories = np.random.choice(categories, N_PRODUCTS)
    name_lengths = np.random.randint(20, 100, N_PRODUCTS)
    description_lengths = np.random.randint(50, 200, N_PRODUCTS)
    photos_qty = np.random.randint(1, 5, N_PRODUCTS)
    weights = np.random.randint(100, 5000, N_PRODUCTS)
    lengths = np.random.randint(10, 100, N_PRODUCTS)
    heights = np.random.randint(1, 50, N_PRODUCTS)
    widths = np.random.randint(5, 70, N_PRODUCTS)
    return pd.DataFrame(
        {
            "product_id": product_ids,
            "product_category_name": product_categories,
            "product_name_length": name_lengths,
            "product_description_length": description_lengths,
            "product_photos_qty": photos_qty,
            "product_weight_g": weights,
            "product_length_cm": lengths,
            "product_height_cm": heights,
            "product_width_cm": widths,
        }
    )


def generate_category_translations(categories: list[str]) -> pd.DataFrame:
    """Create a simple category translation table (here identical)."""
    return pd.DataFrame(
        {
            "product_category_name": categories,
            "product_category_name_english": categories,
        }
    )


def generate_orders(customers: pd.DataFrame) -> pd.DataFrame:
    """Create a synthetic orders table."""
    order_ids = [gen_id(32) for _ in range(N_ORDERS)]
    order_customers = np.random.choice(customers["customer_id"], N_ORDERS)
    statuses = np.random.choice(
        ["delivered", "shipped", "canceled", "invoiced", "processing"],
        N_ORDERS,
        p=[0.7, 0.1, 0.05, 0.1, 0.05],
    )
    start_date = datetime.datetime(2023, 1, 1)
    end_date = datetime.datetime(2023, 12, 31)
    purchase_dates: list[datetime.datetime] = []
    for _ in range(N_ORDERS):
        delta_seconds = random.randint(0, int((end_date - start_date).total_seconds()))
        purchase_dates.append(start_date + datetime.timedelta(seconds=delta_seconds))
    approved_dates = [d + datetime.timedelta(days=random.randint(0, 3)) for d in purchase_dates]
    carrier_dates = [d + datetime.timedelta(days=random.randint(1, 5)) for d in approved_dates]
    customer_dates = []
    for carrier_date, status in zip(carrier_dates, statuses):
        if status == "delivered":
            customer_dates.append(carrier_date + datetime.timedelta(days=random.randint(1, 7)))
        else:
            customer_dates.append(pd.NaT)
    estimated_dates = [d + datetime.timedelta(days=random.randint(3, 10)) for d in purchase_dates]
    return pd.DataFrame(
        {
            "order_id": order_ids,
            "customer_id": order_customers,
            "order_status": statuses,
            "order_purchase_timestamp": purchase_dates,
            "order_approved_at": approved_dates,
            "order_delivered_carrier_date": carrier_dates,
            "order_delivered_customer_date": customer_dates,
            "order_estimated_delivery_date": estimated_dates,
        }
    )


def generate_order_items(
    orders: pd.DataFrame, products: pd.DataFrame, sellers: pd.DataFrame
) -> pd.DataFrame:
    """Create a synthetic order items table."""
    order_items_data: list[list] = []
    for oid, purchase_date in zip(orders["order_id"], orders["order_purchase_timestamp"]):
        n_items = random.randint(1, 3)
        product_choices = random.sample(list(products["product_id"]), n_items)
        for idx, pid in enumerate(product_choices, start=1):
            sid = random.choice(list(sellers["seller_id"]))
            price = round(random.uniform(10, 500), 2)
            freight = round(random.uniform(2, 50), 2)
            shipping_limit = purchase_date + datetime.timedelta(days=random.randint(1, 7))
            order_items_data.append(
                [
                    oid,
                    idx,
                    pid,
                    sid,
                    shipping_limit,
                    price,
                    freight,
                ]
            )
    return pd.DataFrame(
        order_items_data,
        columns=[
            "order_id",
            "order_item_id",
            "product_id",
            "seller_id",
            "shipping_limit_date",
            "price",
            "freight_value",
        ],
    )


def generate_payments(order_items: pd.DataFrame) -> pd.DataFrame:
    """Create a synthetic payments table."""
    payment_records: list[list] = []
    payment_types = ["credit_card", "boleto", "voucher", "debit_card"]
    # Group by order to compute totals
    grouped = order_items.groupby("order_id").agg({"price": "sum", "freight_value": "sum"})
    for oid, row in grouped.iterrows():
        total_value = row["price"] + row["freight_value"]
        n_payments = 1 if random.random() < 0.9 else 2
        installments = random.randint(1, 6)
        for seq in range(1, n_payments + 1):
            ptype = random.choices(payment_types, weights=[0.75, 0.15, 0.05, 0.05])[0]
            value = round(total_value / n_payments + random.uniform(-5, 5), 2)
            payment_records.append([oid, seq, ptype, installments, value])
    return pd.DataFrame(
        payment_records,
        columns=[
            "order_id",
            "payment_sequential",
            "payment_type",
            "payment_installments",
            "payment_value",
        ],
    )


def generate_reviews(orders: pd.DataFrame) -> pd.DataFrame:
    """Create a synthetic order reviews table."""
    review_records: list[list] = []
    for oid, approved_date in zip(
        orders["order_id"], orders["order_approved_at"]
    ):
        review_id = gen_id(32)
        score = random.randint(1, 5)
        creation = approved_date + datetime.timedelta(days=random.randint(5, 40))
        answer = creation + datetime.timedelta(days=random.randint(1, 10))
        review_records.append(
            [review_id, oid, score, "", "", creation, answer]
        )
    return pd.DataFrame(
        review_records,
        columns=[
            "review_id",
            "order_id",
            "review_score",
            "review_comment_title",
            "review_comment_message",
            "review_creation_date",
            "review_answer_timestamp",
        ],
    )


def main() -> None:
    # Generate each table
    customers = generate_customers()
    sellers = generate_sellers()
    products = generate_products()
    translations = generate_category_translations(products["product_category_name"].unique().tolist())
    orders = generate_orders(customers)
    order_items = generate_order_items(orders, products, sellers)
    payments = generate_payments(order_items)
    reviews = generate_reviews(orders)

    # Save to CSV
    customers.to_csv(os.path.join(DATA_DIR, "customers.csv"), index=False)
    sellers.to_csv(os.path.join(DATA_DIR, "sellers.csv"), index=False)
    products.to_csv(os.path.join(DATA_DIR, "products.csv"), index=False)
    translations.to_csv(os.path.join(DATA_DIR, "product_category_translation.csv"), index=False)
    orders.to_csv(os.path.join(DATA_DIR, "orders.csv"), index=False)
    order_items.to_csv(os.path.join(DATA_DIR, "order_items.csv"), index=False)
    payments.to_csv(os.path.join(DATA_DIR, "order_payments.csv"), index=False)
    reviews.to_csv(os.path.join(DATA_DIR, "order_reviews.csv"), index=False)

    print("Data generation complete.")


if __name__ == "__main__":
    main()