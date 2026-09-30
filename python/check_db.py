from sqlalchemy import create_engine, text

engine = create_engine("postgresql://postgres:Olist%40123@localhost:5432/shopkart_analytics")
with engine.connect() as c:
    print(c.execute(text("SELECT current_database(), inet_server_port(), version()")).fetchone())
    print(c.execute(text("SELECT COUNT(*) FROM olist.orders")).scalar())