from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class TemperatureInput(BaseModel):
    temperature: float
    type: str

class TemperatureOutput(BaseModel):
    result: float

@app.post("/convert2")
def convert_temperature(data: TemperatureInput):
    if data.type == "C":
        result = data.temperature * 9/5 + 32
    elif data.type == "F":
        result = (data.temperature - 32) * 5/9
    else:
        result = None
    return {"result": result}