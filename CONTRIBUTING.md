# Contributing

Welcome to the contributor guide of Database Migration Assessment.

This document focuses on getting any potential contributor familiarized with
the development processes, but [other kinds of contributions] are also appreciated.

If you are new to using [git] or have never collaborated in a project previously,
please have a look at [contribution-guide.org]. Other resources are also
listed in the excellent [guide created by FreeCodeCamp] [^contrib1].

Please notice, all users and contributors are expected to be **open,
considerate, reasonable, and respectful**. When in doubt, please refer to [Google's Open Source Community Guidelines].

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement. You (or your employer) retain the copyright to your contribution;
this simply gives us permission to use and redistribute your contributions as
part of the project. Head over to <https://cla.developers.google.com/> to see
your current agreements on file or to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Issue Reports

If you experience bugs or general issues with DMA, please have a look
on the [issue tracker].
If you don't see anything useful there, please feel free to fire an issue report.

!!! tip
    Please don't forget to include the closed issues in your search.
    Sometimes a solution was already reported, and the problem is considered
    **solved**.

New issue reports should include information about your programming environment
(e.g., operating system, Python version) and steps to reproduce the problem.
Please try also to simplify the reproduction steps to a very minimal example
that still illustrates the problem you are facing. By removing other factors,
you help us to identify the root cause of the issue.

## Documentation improvements

You can help improve the documentation of DMA by making them more readable
and coherent, or by adding missing information and correcting mistakes.

This documentation uses [mkdocs] as its main documentation compiler.
This means that the docs are kept in the same repository as the project code, and
that any documentation update is done in the same way was a code contribution.

!!! tip
      Please notice that the [GitHub web interface] provides a quick way for
      proposing changes. While this mechanism can  be tricky for normal code contributions,
      it works perfectly fine for contributing to the docs, and can be quite handy.
      If you are interested in trying this method out, please navigate to
      the `docs` folder in the source [repository], find which file you
      would like to propose changes and click in the little pencil icon at the
      top, to open [GitHub's code editor]. Once you finish editing the file,
      please write a message in the form at the bottom of the page describing
      which changes have you made and what are the motivations behind them and
      submit your proposal.

When working on documentation changes in your local machine, you can
build and serve them using [hatch] with `hatch run docs:build` and
`hatch run docs:serve`, respectively.

## Code Contributions

### Submit an issue

Before you work on any non-trivial code contribution it's best to first create
a report in the [issue tracker] to start a discussion on the subject.
This often provides additional considerations and avoids unnecessary work.

### Clone the repository

1. Create a user account on GitHub if you do not already have one.

2. Fork the project [repository]: click on the *Fork* button near the top of the
   page. This creates a copy of the code under your account on GitHub.

3. Clone this copy to your local disk:

   ```console
   git clone git@github.com:YourLogin/dma.git
   cd dma
   ```

4. Make sure [hatch] is installed using [pipx]:

   ```console
   pipx install hatch
   ```

5. \[only once\] install [pre-commit] hooks in the default environment with:

   ```console
   hatch run pre-commit install
   ```

### Implement your changes

1. Create a branch to hold your changes:

   ```console
   git checkout -b my-feature
   ```

   and start making changes. Never work on the main branch!

2. Start your work on this branch. Don't forget to add [docstrings] in [Google style]
   to new functions, modules and classes, especially if they are part of public APIs.

3. Add yourself to the list of contributors in `AUTHORS.md`.

4. When you’re done editing, do:

   ```console
   git add <MODIFIED FILES>
   git commit
   ```

   to record your changes in [git].

   Please make sure to see the validation messages from [pre-commit] and fix
   any eventual issues.
   This should automatically use [ruff] to check/fix the code style
   in a way that is compatible with the project.

    !!! info
        Don't forget to add unit tests and documentation in case your
        contribution adds a feature and is not just a bugfix. Writing an [descriptive commit message] is highly recommended.
        In case of doubt, you can check the commit history with:
        ```
        git log --graph --decorate --pretty=oneline --abbrev-commit --all
        ```
        to look for recurring communication patterns.

5. Please check that your changes don't break any unit tests with
   `hatch run test:cov` or `hatch run test:no-cov` to run the tests with
   or without coverage reports, respectively.

### Submit your contribution

1. If everything works fine, push your local branch to the remote server with:

    ```console
    git push -u origin my-feature
    ```

2. Go to the web page of your fork and click "Create pull request"
   to send your changes for review.

   Find more detailed information in [creating a PR]. You might also want to open
   the PR as a draft first and mark it as ready for review after the feedbacks
   from the continuous integration (CI) system or any required fixes.

[^contrib1]: Even though, these resources focus on open source projects and
    communities, the general ideas behind collaborating with other developers
    to collectively create software are general and can be applied to all sorts
    of environments, including private companies and proprietary code bases.

[ruff]: https://docs.astral.sh/ruff/
[contribution-guide.org]: http://www.contribution-guide.org/
[creating a PR]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request
[docstrings]: https://peps.python.org/pep-0257/
[git]: https://git-scm.com
[github web interface]: https://docs.github.com/en/github/managing-files-in-a-repository/managing-files-on-github/editing-files-in-your-repository
[other kinds of contributions]: https://opensource.guide/how-to-contribute
[pre-commit]: https://pre-commit.com/
[pipx]: https://pypa.github.io/pipx/
[Google's Open Source Community Guidelines]:  https://opensource.google/conduct/
[Google style]: https://google.github.io/styleguide/pyguide.html#38-comments-and-docstrings
[guide created by FreeCodeCamp]: https://github.com/FreeCodeCamp/how-to-contribute-to-open-source
