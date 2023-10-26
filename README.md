To add a new post,

1. create new sub-directory `DD-MM-YYYY-name` in directory `posts/`.
2. Write your post inside this sub-folder as a qmd file, with the appropriate preamble, see [here](https://quarto.org/docs/websites/website-blog.html#posts-directory).
3. Compile, `quarto render .`, check the result in your browser, e.g. `firefox docs/index.html`
4. `git add` new files, `git commit -a` and `git push`
