# Disable automatic camelization in tests for easier assertions
Application.put_env(:nb_serializer, :camelize_props, false)

ExUnit.start()
