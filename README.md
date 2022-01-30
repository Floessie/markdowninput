# markdowninput

`markdowninput.sty` defines the command `\markdownInput{FILENAME}` which reads the given rudimentary Markdown file and converts it to LaTeX on the fly using Lua.

This is a specially tailored solution to my novel typesetting workflow without bells and whistles apart from automatic dropcaps on the first letter of a chapter. Please see `markdowninput.lua` for the details.

If you just want to typeset Markdown in LaTeX, please see the wonderful [`markdown`](https://ctan.org/pkg/markdown) package.

This was conceived as an answer to [my question on `tex.stackexchange.com`](https://tex.stackexchange.com/q/630200).
