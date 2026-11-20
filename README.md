# LionClub

A personal iPhone app for a Peugeot 2008 (2020, petrol).

Unofficial: not affiliated with or endorsed by Peugeot, Stellantis, NIS or Gazprom.

> Early stage. The first step is finding out whether Peugeot's servers have live data for the car.

## What it will do
- **If Peugeot's servers have live data for the car:** show its status: fuel, range, odometer, lock state and next service.
- **If they don't:** work as an offline companion, with the parking spot, trips and a fuel log, triggered by CarPlay or Bluetooth.
- **Fuel stations:** a map of NIS Petrol and Gazprom stations in Serbia, with the government's weekly maximum fuel prices.
- **Shortcuts:** Home Screen and Lock Screen widgets, plus Siri and Control Center actions.

## Step 1: Peugeot cloud test (Windows)
Run this in PowerShell from the project folder:

```powershell
powershell -ExecutionPolicy Bypass -File tools\peugeot-cloud-test.ps1
```

1. The script opens Peugeot's own login page in your browser. You sign in there, never in the script.
2. Paste the `mymap://` code from the browser back into the script.
3. It prints whether Peugeot's servers have live data for the car.

Nothing is saved. Add `-SaveSample` to keep a copy of the car's status with the VIN, ids and position removed.

## Building without a Mac
GitHub Actions builds the app on a macOS runner for every push. Each build publishes an unsigned `LionClub.ipa` and Simulator screenshots as build artifacts.

## Installing on an iPhone with a free Apple ID
Install `LionClub.ipa` with [AltStore](https://altstore.io) (AltServer for Windows) or [SideStore](https://sidestore.io).

With a free Apple ID, the app has to be refreshed every 7 days. Both tools can do this automatically. Sideloadly works too, but it can strip the widget extension.

## License
GPL-3.0. Third-party code and data sources are listed in [NOTICE.md](NOTICE.md).
