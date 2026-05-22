#pragma once

#include "esphome/components/sensor/sensor.h"
#include "esphome/components/uart/uart.h"
#include "esphome/core/component.h"
#include "esphome/core/log.h"
#include <bitset>

namespace esphome {
namespace loctek_height_sensor {

static const char *const TAG = "loctek_height_sensor";

class LoctekHeightSensor : public Component, public uart::UARTDevice, public sensor::Sensor {
public:
  float value = -1;
  float lastPublished = -1;
  unsigned long history[5]{};

  int msg_len = 0;
  unsigned long msg_type = 0;
  bool valid = false;

  float get_setup_priority() const override { return esphome::setup_priority::DATA; }

  void dump_config() override
  {
    ESP_LOGCONFIG(TAG, "Loctek Height Sensor:");
  }

  int hex_to_int(uint8_t s)
  {
    std::bitset<8> b(s);

    if (b[0] && b[1] && b[2] && b[3] && b[4] && b[5] && !b[6])
    {
      return 0;
    }
    if (not b[0] && b[1] && b[2] && !b[3] && !b[4] && !b[5] && !b[6])
    {
      return 1;
    }
    if (b[0] && b[1] && !b[2] && b[3] && b[4] && !b[5] && b[6])
    {
      return 2;
    }
    if (b[0] && b[1] && b[2] && b[3] && !b[4] && !b[5] && b[6])
    {
      return 3;
    }
    if (not b[0] && b[1] && b[2] && !b[3] && !b[4] && b[5] && b[6])
    {
      return 4;
    }
    if (b[0] && !b[1] && b[2] && b[3] && !b[4] && b[5] && b[6])
    {
      return 5;
    }
    if (b[0] && !b[1] && b[2] && b[3] && b[4] && b[5] && b[6])
    {
      return 6;
    }
    if (b[0] && b[1] && b[2] && !b[3] && !b[4] && !b[5] && !b[6])
    {
      return 7;
    }
    if (b[0] && b[1] && b[2] && b[3] && b[4] && b[5] && b[6])
    {
      return 8;
    }
    if (b[0] && b[1] && b[2] && b[3] && !b[4] && b[5] && b[6])
    {
      return 9;
    }
    if (!b[0] && !b[1] && !b[2] && !b[3] && !b[4] && !b[5] && b[6])
    {
      return 10;
    }
    return 0;
  }

  bool is_decimal(uint8_t b)
  {
    return (b & 0x80) == 0x80;
  }

  void setup() override
  {
    // nothing to do here
  }

  void loop() override
  {
    while (available() > 0)
    {
      uint8_t incomingByte = read();

      if (incomingByte == 0x9b)
      {
        msg_len = 0;
        valid = false;
      }

      if (history[0] == 0x9b)
      {
        msg_len = (int)incomingByte;
      }

      if (history[1] == 0x9b)
      {
        msg_type = incomingByte;
      }

      if (history[2] == 0x9b)
      {
        if (msg_type == 0x12 && msg_len == 7)
        {
          if (incomingByte != 0)
          {
            valid = true;
          }
        }
      }

      if (history[4] == 0x9b)
      {
        if (valid == true)
        {
          int height1 = hex_to_int(history[1]) * 100;
          int height2 = hex_to_int(history[0]) * 10;
          int height3 = hex_to_int(incomingByte);
          if (height2 != 100)
          {
            float finalHeight = height1 + height2 + height3;
            if (is_decimal(history[0]))
            {
              finalHeight = finalHeight / 10;
            }
            value = finalHeight;
          }
        }
      }

      history[4] = history[3];
      history[3] = history[2];
      history[2] = history[1];
      history[1] = history[0];
      history[0] = incomingByte;

      if (incomingByte == 0x9d)
      {
        if (value != -1 && value != lastPublished)
        {
          publish_state(value);
          lastPublished = value;
        }
      }
    }
  }
};

}  // namespace loctek_height_sensor
}  // namespace esphome
