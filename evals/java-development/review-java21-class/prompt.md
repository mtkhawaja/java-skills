---
tags: [java-development]
max_turns: 30
allowed_tools: [Read, Glob, Grep, Skill]
---

Review this class from a Maven project whose pom sets <release>21</release>. List every convention violation, then output the fixed version.

```java
import java.util.ArrayList;
import java.util.Optional;

public class ShippingCalculator {
    public static final int STANDARD = 0;
    public static final int EXPRESS = 1;
    public static final int OVERNIGHT = 2;

    private Optional<String> promoCode = Optional.empty();
    private ArrayList rates = new ArrayList();

    public double cost(int method, double weight, String destination) {
        double result = 0;
        if (destination != null) {
            if (!destination.isBlank()) {
                if (weight > 0) {
                    if (method == STANDARD) { result = 5.0 + weight * 0.5; }
                    else if (method == EXPRESS) { result = 10.0 + weight * 0.75; }
                    else if (method == OVERNIGHT) { result = 25.0 + weight * 1.5; }
                } else {
                    throw new RuntimeException("bad weight");
                }
            }
        }
        return result;
    }

    public boolean equals(Object o) {
        return o instanceof ShippingCalculator;
    }
}
```
