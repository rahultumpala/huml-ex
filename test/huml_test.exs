defmodule HUMLTest do
  use ExUnit.Case
  doctest HUML

  @tag run: false
  test "greets the world" do
    assert HUML.hello() == :i_am_huml
  end

  @tag run: false
  test "simple" do
    txt = """
    %HUML v0.1.0

    "foo"
    simple_key
    1.234
    +3.12e+123
    0xAF
    0b00010
    0o31
    nan
    inf
    """

    HUML.decode(txt) |> IO.inspect(limit: :infinity)
    IO.puts("\n\n")
    assert true
  end

  @tag run: false
  test "inline_list" do
    txt = """
    %HUML v0.1.0

    "foo", simple_key, 1.234
    """

    HUML.decode(txt) |> IO.inspect(limit: :infinity)
    IO.puts("\n\n")
    assert true
  end

  @tag run: false
  test "inline dict" do
    txt = """
    %HUML v0.1.0

    "foo": "bar", simple_key: 1.234
    """

    HUML.decode(txt) |> IO.inspect(limit: :infinity)
    IO.puts("\n\n")
    assert true
  end

  @tag run: false
  test "multiline_dict" do
    txt = """
    # Kitchensink test file.
    foo_one:: # Hello
      # Scalar values testing - basic types
      foo_string: "bar_value"
    """

    HUML.decode(txt) |> IO.inspect(limit: :infinity)
    IO.puts("\n\n")
    assert true
  end

  @tag run: false
  test "list variations" do
    txt = """
    # List variations
    data_sources::
      - "primary_db_connection_string"
      - "secondary_api_endpoint_url"
      - "192.168.1.100" # IP address as a string
      - :: # A list of lists
        - "alpha"
        - "beta"
        - "gamma"
      - true # A boolean in a list
    """

    HUML.decode(txt) |> IO.inspect(limit: :infinity)
    IO.puts("\n\n")
    assert true
  end

  @tag run: true
  test "complex, without multiline strings" do
    txt =
      ~S"""
      # This is the root dictionary for our application configuration.
      application_config::
        application_name: "HUML Showcase Suite"
        version: "1.0.0-beta"
        environment: "development" # Can be 'production', 'staging', etc.
        debug_mode: true
        retry_attempts: 5
        timeout_seconds: 30.5
        feature_flags:: # A nested dictionary for feature toggles
          new_dashboard_enabled: true
          user_experiment_ab: false
          "legacy-system.compatibility_mode": true # Quoted key

        # Contact information
        contact_points::
          - :: # List item: inline dictionary for admin
            type: "admin"
            email: "admin@example.com"
            phone: null # Null value example
          - :: # List item: multi-line dictionary for support
            type: "support"
            email: "support@example.com"
            availability::
              weekdays: "9am - 6pm"
              weekends: "10am - 2pm"

        # Numeric data types showcase
        numerical_data::
          integer_val: 1_234_567
          float_val: -0.00789
          scientific_notation_val: 6.022e23
          hex_val: 0xCAFEBABE
          octal_val: 0o755
          binary_val: 0b11011001
          infinity_positive: +inf
          infinity_negative: -inf
          not_a_number: nan
          empty_integer_list:: [] # Empty list
          empty_mapping:: {}    # Empty dictionary

        # String variations
        string_examples::
          simple_greeting: "Hello, \"Universe\"!"
          path_example: "C:\\Users\\Default\\Documents"
          multiline_preserved_poem: ```
            The HUML spec, so clear and bright,
              Makes data shine with pure delight.
            No ambiguity, no YAML fright,
            Just structured sense, and pure insight.
          ```
          multiline_stripped_script: \"""
                #!/bin/bash
                echo "Starting service..."
                # This script has leading spaces stripped.
                  # Even this indented comment.
                exit 0
          \"""

        # List variations
        data_sources::
          - "primary_db_connection_string"
          - "secondary_api_endpoint_url"
          - "192.168.1.100" # IP address as a string
          - :: # A list of lists
            - "alpha"
            - "beta"
            - "gamma"
          - true # A boolean in a list

        inline_collections::
          simple_list:: "red", "green", "blue"
          simple_dict:: color: "yellow", intensity: 0.8, transparent: false
          # List of inline dictionaries
          points_of_interest::
            - :: x: 10, y: 20, label: "Start"
            - :: x: 15, y: 25, label: "Checkpoint 1"
            - :: x: 30, y: 10, label: "End"

        # Example of a more complex nested structure
        server_nodes::
          - :: # First server node (dictionary)
            id: "node-alpha-001"
            ip_address: "10.0.0.1"
            roles:: "web", "api" # Inline list
            status: "active"
            "metadata with space": "custom server info" # Quoted key
            config_file_content: ```
              # Sample config for node-alpha-001
              port = 8080
              threads = 16
            ```
          - :: # Second server node (dictionary)
            id: "node-beta-002"
            ip_address: "10.0.0.2"
            roles::
              - "database_primary"
              - "replication_master"
            status: "pending_maintenance"
            hardware_specs::
              cpu_cores: 8
              ram_gb: 64
              storage_tb: 2

      # Another top-level key, independent of 'application_config'
      # This demonstrates that a HUML file can have multiple top-level keys,
      # implicitly forming a root dictionary.
      user_preferences::
        theme: "solarized_dark"
        font_size_pt: 12
        show_tooltips: true
      """

    HUML.decode(txt) |> IO.inspect(limit: :infinity)
    IO.puts("\n\n")
    assert true
  end

  @tag run: false
  test "mutiline_strings" do
    txt = ~S"""
    %HUML v0.1.0

    with_spaces: ```
      some
      multiline
      text
      here
    ```

    without_spaces: \"""
      some
      multiline
      text
      here
    \"""
    """

    HUML.decode(txt) |> IO.inspect(limit: :infinity)
    IO.puts("\n\n")
  end
end
