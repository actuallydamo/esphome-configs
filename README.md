# ESPHome Configs

This repository contains my ESPHome configuration files for various smart home devices.

## Files

### Configuration Files

- **[`configs/base.yaml`](configs/base.yaml)** - Base ESPHome configuration:
  - WiFi setup with fallback hotspot
  - Home Assistant API integration
  - OTA updates
  - Uptime sensor
  - Logging configuration
  - Restart button

- **[`configs/base.ac.yaml`](configs/base.ac.yaml)** - MHI air conditioner specific configuration

- **[`configs/mhi-version.txt`](configs/mhi-version.txt)** - Track current MHI version

### Scripts

- **[`scripts/mhi-yaml-base-update.sh`](scripts/mhi-yaml-base-update.sh)** - Automated update script that will:
  - Check for new upstream releases
  - Download and merge the latest configurations
  - Update the base.ac.yaml file
  - Show diff between versions
  - Validate the updated configuration files

## Usage

### Setting up a new device

1. Create a new ESPHome configuration file for your device
2. Include the base configuration/s:
   ```yaml
   packages:
     # ac: !include configs/base.ac.yaml
     base: !include configs/base.yaml

   substitutions:
     device_id: "device-name"
     friendly_name: "Device Name"
     ip_address: 10.1.1.x
   ```

3. Add device-specific configurations as needed

## Contributing

This repo is my personal device configurations and is not intended for public contributions.
Feel free to use the configurations as a reference for your own ESPHome projects.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [MHI-AC-Ctrl-ESPHome](https://github.com/ginkage/MHI-AC-Ctrl-ESPHome) - The upstream project for MHI air conditioner control
- [ESPHome](https://esphome.io/)
