/*
    create_tables.sql

    This script defines the schema for a small e‑commerce sales and retention
    warehouse using T‑SQL.  It creates a new database named
    `ECommerceMiniDW` and populates a set of dimension and fact tables
    appropriate for analysing orders, order items, payments and reviews.

    The schema adopts a star‑shaped layout with date, customer, product,
    seller, category, payment type and review score dimensions.  Fact tables
    capture orders, order items, payments and reviews.  Keys are generated as
    integer identities where appropriate to ensure efficient joins.  Date
    keys are stored in `YYYYMMDD` integer format so that they can be easily
    partitioned by year and month.
*/

-- Create the database if it does not already exist
IF DB_ID('ECommerceMiniDW') IS NULL
    CREATE DATABASE ECommerceMiniDW;
GO

USE ECommerceMiniDW;
GO

/*
    Drop the fact and dimension tables if they exist.  This allows the script
    to be rerun without manually cleaning up the database.  The order of
    deletion respects foreign key dependencies (fact tables first, then
    dimensions).
*/
IF OBJECT_ID('fact_reviews') IS NOT NULL DROP TABLE fact_reviews;
IF OBJECT_ID('fact_payments') IS NOT NULL DROP TABLE fact_payments;
IF OBJECT_ID('fact_order_items') IS NOT NULL DROP TABLE fact_order_items;
IF OBJECT_ID('fact_orders') IS NOT NULL DROP TABLE fact_orders;

IF OBJECT_ID('dim_review_score') IS NOT NULL DROP TABLE dim_review_score;
IF OBJECT_ID('dim_payment_type') IS NOT NULL DROP TABLE dim_payment_type;
IF OBJECT_ID('dim_category') IS NOT NULL DROP TABLE dim_category;
IF OBJECT_ID('dim_product') IS NOT NULL DROP TABLE dim_product;
IF OBJECT_ID('dim_seller') IS NOT NULL DROP TABLE dim_seller;
IF OBJECT_ID('dim_customer') IS NOT NULL DROP TABLE dim_customer;
IF OBJECT_ID('dim_date') IS NOT NULL DROP TABLE dim_date;
GO

/*
    Dimension tables

    dim_date: Stores a calendar date with useful components for time based
    aggregations.  The surrogate key is stored as an integer in YYYYMMDD
    format.  Weekday uses SQL Server's DATEPART(WEEKDAY) convention.
*/
CREATE TABLE dim_date (
    date_key          INT          NOT NULL PRIMARY KEY, -- YYYYMMDD
    full_date         DATE         NOT NULL,
    year              INT          NOT NULL,
    quarter           INT          NOT NULL,
    month             INT          NOT NULL,
    day_of_month      INT          NOT NULL,
    day_of_week       INT          NOT NULL
);

/*
    dim_customer: Contains the customer identifiers from the source system as
    well as simple location attributes.  A surrogate key (identity) is used
    for efficient joins in the fact tables.
*/
CREATE TABLE dim_customer (
    customer_key          INT            IDENTITY(1,1) PRIMARY KEY,
    customer_id           VARCHAR(32)    NOT NULL,
    customer_unique_id    VARCHAR(32)    NOT NULL,
    zip_code_prefix       VARCHAR(10)    NULL,
    city                  NVARCHAR(100)  NULL,
    state                 NVARCHAR(10)   NULL
);

/*
    dim_seller: Contains seller identifiers and location attributes.
*/
CREATE TABLE dim_seller (
    seller_key            INT            IDENTITY(1,1) PRIMARY KEY,
    seller_id             VARCHAR(32)    NOT NULL,
    zip_code_prefix       VARCHAR(10)    NULL,
    city                  NVARCHAR(100)  NULL,
    state                 NVARCHAR(10)   NULL
);

/*
    dim_category: Stores product categories and their translations.  The
    category_key provides a single point of reference for the category
    attribute on the product dimension.
*/
CREATE TABLE dim_category (
    category_key          INT            IDENTITY(1,1) PRIMARY KEY,
    category_name         NVARCHAR(100)  NOT NULL,
    category_name_en      NVARCHAR(100)  NOT NULL
);

/*
    dim_product: Contains product attributes.  Each product references a
    category via the category_key foreign key.  Physical measurements are
    stored in metric units.
*/
CREATE TABLE dim_product (
    product_key           INT            IDENTITY(1,1) PRIMARY KEY,
    product_id            VARCHAR(32)    NOT NULL,
    category_key          INT            NOT NULL REFERENCES dim_category(category_key),
    name_length           INT            NULL,
    description_length    INT            NULL,
    photos_qty            INT            NULL,
    weight_g              INT            NULL,
    length_cm             INT            NULL,
    height_cm             INT            NULL,
    width_cm              INT            NULL
);

/*
    dim_payment_type: Captures the different payment methods used on the
    platform.  Values could include credit_card, boleto, voucher and
    debit_card.
*/
CREATE TABLE dim_payment_type (
    payment_type_key      INT            IDENTITY(1,1) PRIMARY KEY,
    payment_type          NVARCHAR(50)   NOT NULL
);

/*
    dim_review_score: Normalises the review scores given by customers.
*/
CREATE TABLE dim_review_score (
    review_score_key      INT            IDENTITY(1,1) PRIMARY KEY,
    review_score          INT            NOT NULL
);

/*
    Fact tables

    fact_orders: Stores one row per order.  It references the customer
    dimension and multiple date dimensions.  Fact tables avoid surrogate
    keys for the order identifier because the natural order_id is unique.
*/
CREATE TABLE fact_orders (
    order_id                    VARCHAR(32)    PRIMARY KEY,
    customer_key                INT            NOT NULL REFERENCES dim_customer(customer_key),
    order_status                NVARCHAR(20)   NOT NULL,
    order_date_key              INT            NOT NULL REFERENCES dim_date(date_key),
    approved_date_key           INT            NOT NULL REFERENCES dim_date(date_key),
    delivered_carrier_date_key  INT            NULL REFERENCES dim_date(date_key),
    delivered_customer_date_key INT            NULL REFERENCES dim_date(date_key),
    estimated_delivery_date_key INT            NOT NULL REFERENCES dim_date(date_key)
);

/*
    fact_order_items: Contains order item level information such as product,
    seller, shipping date and financial measures.  An order can have
    multiple items.  The combination of order_id and order_item_id forms
    the primary key.
*/
CREATE TABLE fact_order_items (
    order_id               VARCHAR(32)    NOT NULL,
    order_item_id          INT            NOT NULL,
    product_key            INT            NOT NULL REFERENCES dim_product(product_key),
    seller_key             INT            NOT NULL REFERENCES dim_seller(seller_key),
    shipping_date_key      INT            NOT NULL REFERENCES dim_date(date_key),
    price                  DECIMAL(18,2)  NOT NULL,
    freight_value          DECIMAL(18,2)  NOT NULL,
    CONSTRAINT PK_fact_order_items PRIMARY KEY (order_id, order_item_id)
);

/*
    fact_payments: Contains payment details for orders.  There can be
    multiple payments per order (installments).  payment_type_key points
    into dim_payment_type.
*/
CREATE TABLE fact_payments (
    order_id               VARCHAR(32)    NOT NULL,
    payment_seq            INT            NOT NULL,
    payment_type_key       INT            NOT NULL REFERENCES dim_payment_type(payment_type_key),
    payment_installments   INT            NOT NULL,
    payment_value          DECIMAL(18,2)  NOT NULL,
    CONSTRAINT PK_fact_payments PRIMARY KEY (order_id, payment_seq)
);

/*
    fact_reviews: Captures customer review activity.  It stores review
    scores and timestamps in the date dimension.  The fact uses the
    natural review_id as its primary key.
*/
CREATE TABLE fact_reviews (
    review_id              VARCHAR(32)    PRIMARY KEY,
    order_id               VARCHAR(32)    NOT NULL REFERENCES fact_orders(order_id),
    review_score_key       INT            NOT NULL REFERENCES dim_review_score(review_score_key),
    creation_date_key      INT            NOT NULL REFERENCES dim_date(date_key),
    answer_date_key        INT            NOT NULL REFERENCES dim_date(date_key)
);

-- End of create_tables.sql