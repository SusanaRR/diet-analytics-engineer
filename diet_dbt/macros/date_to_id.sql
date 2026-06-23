{% macro date_to_id(date_column) %}
    year({{ date_column }}) * 10000
        + month({{ date_column }}) * 100
        + day({{ date_column }})
{% endmacro %}
