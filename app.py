from flask import Flask, render_template, request, redirect, flash
import pymysql

app = Flask(__name__)
app.secret_key = "replace-with-secure-secret"

# Update with your RDS DB details
DB_HOST = "your-rds-endpoint"
DB_USER = "admin"
DB_PASS = "yourpassword"
DB_NAME = "mydb"

def get_connection():
    try:
        return pymysql.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASS,
            database=DB_NAME
        )
    except Exception:
        app.logger.exception("Database connection failed")
        flash("Database connection failed. Please try again later.", "error")
        return None

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        username = request.form["username"]
        phone = request.form["phone"]
        place = request.form["place"]

        conn = get_connection()
        if not conn:
            return redirect("/")
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO users (username, phone, place) VALUES (%s, %s, %s)",
                    (username, phone, place),
                )
            conn.commit()
        except Exception:
            app.logger.exception("Failed to insert user")
            flash("Unable to save your details. Please try again later.", "error")
        finally:
            conn.close()
        return redirect("/")

    rows = []
    conn = get_connection()
    if conn:
        try:
            with conn.cursor(pymysql.cursors.DictCursor) as cur:
                cur.execute(
                    "SELECT id, username, phone, place FROM users ORDER BY id DESC"
                )
                rows = cur.fetchall()
        except Exception:
            app.logger.exception("Failed to fetch users")
            flash("Unable to load user data.", "error")
        finally:
            conn.close()
    return render_template("form.html", rows=rows)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
