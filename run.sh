#!/usr/bin/with-contenv bashio

export MQTT_BASE=$(bashio::config 'mqtt_base')
export DISCOVERY_PREFIX=$(bashio::config 'discovery_prefix')
export ENABLED_ENTITY=$(bashio::config 'enabled_entity')
export ENTITIES_SELECT=$(bashio::config 'entities_select')
export AREAS_SELECT=$(bashio::config 'areas_select')
export EXCLUDES_SELECT=$(bashio::config 'excludes_select')
export DOMAINS_SELECT=$(bashio::config 'domains_select')
export DEBUG=$(bashio::config 'debug')
export RETAIN=$(bashio::config 'retain')
export DISCOVERY_ON_STARTUP=$(bashio::config 'discovery_on_startup')
export DISCOVERY_ON_DROPDOWN_CHANGE=$(bashio::config 'discovery_on_dropdown_change')
export DISCOVERY_ON_BIRTH=$(bashio::config 'discovery_on_birth')

# Use provided broker config, or fall back to HA system MQTT service
CUSTOM_HOST=$(bashio::config 'broker_host')
if bashio::var.has_value "${CUSTOM_HOST}"; then
    bashio::log.info "Using custom MQTT broker: ${CUSTOM_HOST}"
    export BROKER_HOST="${CUSTOM_HOST}"
    export BROKER_PORT=$(bashio::config 'broker_port')
    export BROKER_USERNAME=$(bashio::config 'broker_username')
    export BROKER_PASSWORD=$(bashio::config 'broker_password')
else
    bashio::log.info "Using HA system MQTT service"
    export BROKER_HOST=$(bashio::services mqtt "host" 2>/dev/null || echo "core-mosquitto")
    export BROKER_PORT=$(bashio::services mqtt "port" 2>/dev/null || echo "1883")
    export BROKER_USERNAME=$(bashio::services mqtt "username" 2>/dev/null || echo "")
    export BROKER_PASSWORD=$(bashio::services mqtt "password" 2>/dev/null || echo "")
fi

bashio::log.info "MQTT broker: ${BROKER_HOST}:${BROKER_PORT}"

python3 /app/main.py