{% macro calculate_bmi(weight_kg, height_cm) %}
    round(
        {{ weight_kg }} / power({{ height_cm }} / 100.0, 2),
        1
    )
{% endmacro %}
