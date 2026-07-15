# Temperature Conversion Microservice API

## Routing Rules
- Create a 'POST /convert' endpoint.
- Input Rule (JSON): {"temperature": 30, "type": "C"} (type must be C or F)

## Business Logic
- If type is "C", convert Celsius to Fahrenheit and return.
- If type is "F", convert Fahrenheit to Celsius and return.
- Output Rule (JSON): {"result": converted_value}