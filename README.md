# Stock Price Listener
Connects to Twelve Data's stock market api via websockets to print stock prices to the command line

## Setup
Create a text file called 'api_key.txt' in the same directory as the script. Insert your twelve data api key inside the file.

## Usage
Run the script in the directory it is located in Powershell. Stock market symbols are added as arguments to indicate which stock prices to subscribe to. No arguments defaults to subscribing to 'BTC/USD'. CTRL + C to stop the script.

Default no arguments (Defaults to BTC/USD):
```sh
.\price_listener.ps1
```

With arguments:
```sh
.\price_listener.ps1 AAPL BTC/USD
```

