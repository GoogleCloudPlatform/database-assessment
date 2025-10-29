# Error Handling

**Objective**: This document explains the error handling strategy for the `dma` tool.

## 1. Core Concept

The tool uses a custom exception hierarchy to handle application-specific errors. This allows for more specific error handling and makes it easier to debug issues.

## 2. Project-Specific Implementation

The base exception class is `ApplicationError` in `src/dma/lib/exceptions.py`. All other application-specific exceptions should inherit from this class.

### Pattern

The error handling strategy is based on a simple **Custom Exception Hierarchy**. This allows for a clear and consistent way to handle errors throughout the application.

### Code Example

Here is an example of how to define a new custom exception:

```Python
from dma.lib.exceptions import ApplicationError

class MyCustomError(ApplicationError):
    """My custom error."""
```

Here is an example of how to raise a custom exception:

```Python
from my_module import MyCustomError

def my_function():
    raise MyCustomError("Something went wrong.")
```

Here is an example of how to catch a custom exception:

```Python
from my_module import MyCustomError

try:
    my_function()
except MyCustomError as e:
    print(f"An error occurred: {e}")
```

## 3. How to Use

To create a new custom exception, you need to:

1.  Create a new class that inherits from `ApplicationError`.
2.  Add a docstring to the class that explains the purpose of the exception.

## 4. Troubleshooting

-   **Unhandled exceptions**: If you encounter an unhandled exception, it may be a bug in the code. Consider adding a new custom exception to handle the error more gracefully.
