from fastapi import FastAPI
from fastapi.responses import RedirectResponse

consoles = (
    {
        "id": 1,
        "make": "Microsoft",
        "model": "Xbox",
        "gen": "One"
    },
    {
        "id": 2,
        "make": "Sony",
        "model": "PlayStation",
        "gen": "5"
    },
    {
        "id": 3,
        "make": "Nintendo",
        "model": "Switch",
        "gen": "Slim"
    }
)

app = FastAPI()

@app.get("/")
def get_docs():
    return RedirectResponse("/docs")

@app.get("/consoles")
def get_consoles():
    return consoles

@app.get("/consoles/{id}")
def get_console(id: int):
    console = list(filter(lambda x: x['id'] == id, consoles))[0]
    return console
