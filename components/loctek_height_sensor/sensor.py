import esphome.codegen as cg
from esphome.components import sensor, uart
from esphome.const import CONF_ID

DEPENDENCIES = ["uart"]

loctek_height_sensor_ns = cg.esphome_ns.namespace("loctek_height_sensor")
LoctekHeightSensor = loctek_height_sensor_ns.class_(
    "LoctekHeightSensor", sensor.Sensor, cg.Component, uart.UARTDevice
)

CONFIG_SCHEMA = sensor.sensor_schema(
    LoctekHeightSensor,
    unit_of_measurement="cm",
    accuracy_decimals=1,
    icon="mdi:counter",
).extend(uart.UART_DEVICE_SCHEMA)


async def to_code(config):
    var = cg.new_Pvariable(config[CONF_ID])
    await cg.register_component(var, config)
    await sensor.register_sensor(var, config)
    await uart.register_uart_device(var, config)
