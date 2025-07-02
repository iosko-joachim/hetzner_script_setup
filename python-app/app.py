from fastapi import FastAPI, Response
import yfinance as yf
import matplotlib.pyplot as plt
import io
from datetime import datetime, timedelta

app = FastAPI()

@app.get("/")
def root():
    return {"message": "Python-Backend läuft."}

@app.get("/plot")
def plot_sp500():
    days = 200

    # S&P 500 abrufen (Ticker: ^GSPC)
    end = datetime.today()
    start = end - timedelta(days=days)
    data = yf.download("^GSPC", start=start, end=end)

    # Diagramm erzeugen
    plt.figure(figsize=(10, 5))
    plt.plot(data.index, data["Close"], label="S&P 500")
    plt.title(f"S&P 500 – Letzte {days} Tage")
    plt.xlabel("Datum")
    plt.ylabel("Schlusskurs")
    plt.grid(True)
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.legend()

    # Diagramm in Bytes umwandeln
    buf = io.BytesIO()
    plt.savefig(buf, format="png")
    plt.close()
    buf.seek(0)

    return Response(content=buf.read(), media_type="image/png")