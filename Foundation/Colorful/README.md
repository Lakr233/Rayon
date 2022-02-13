# Colorful

A SwiftUI implementation of AppleCard's animated colorful blur background.

## Preview

![Preview](./Preview.png)

## Usage

```
import Colorful

var body: some View {
    ColorfulView()
}
```

## Customization & Defaults

```
init(
    animated: Bool = defaultAnimated,
    animation: Animation = defaultAnimation,
    blurRadius: CGFloat = defaultBlurRadius,
    colors: [Color] = defaultColorList,
    colorCount: Int = defaultColorCount
)
```

## License

Colorful is licensed under [MIT](./LICENSE).

---

Copyright © 2021 Lakr Aream. All Rights Reserved.