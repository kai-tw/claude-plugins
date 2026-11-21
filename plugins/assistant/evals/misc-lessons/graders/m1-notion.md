---
type: regex
pattern: '^skills/assistant/references/notion\.md: .*(((child|sub-?page)[^.]*trash|trash[^.]*(child|sub-?page)).*((only|just)[^.]*blocks?|blocks?[^.]*(only|just)).*(replac|overwrit|rewrit)|((child|sub-?page)[^.]*trash|trash[^.]*(child|sub-?page)).*(replac|overwrit|rewrit).*((only|just)[^.]*blocks?|blocks?[^.]*(only|just))|((only|just)[^.]*blocks?|blocks?[^.]*(only|just)).*((child|sub-?page)[^.]*trash|trash[^.]*(child|sub-?page)).*(replac|overwrit|rewrit)|((only|just)[^.]*blocks?|blocks?[^.]*(only|just)).*(replac|overwrit|rewrit).*((child|sub-?page)[^.]*trash|trash[^.]*(child|sub-?page))|(replac|overwrit|rewrit).*((child|sub-?page)[^.]*trash|trash[^.]*(child|sub-?page)).*((only|just)[^.]*blocks?|blocks?[^.]*(only|just))|(replac|overwrit|rewrit).*((only|just)[^.]*blocks?|blocks?[^.]*(only|just)).*((child|sub-?page)[^.]*trash|trash[^.]*(child|sub-?page)))'
flags: mi
---
[M1] notion.md: replacing a page's whole body trashes its child pages; check for children first and, when there are any, edit only the blocks that change.
