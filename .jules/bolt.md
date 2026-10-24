## 2024-10-24 - Optimize string operations in loops
 **Learning:** Repeated string operations, such as `toLowerCase()`, within tight loops can introduce measurable performance overhead.
 **Action:** Hoist repetitive operations that do not depend on the loop iterator out of loops. For example, assign `bookName.toLowerCase()` to a variable before entering a loop to iterate mapping entries.
