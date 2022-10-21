# telemetry-lambda-resources

[![Brought to you by Telemetry Team](https://img.shields.io/badge/MDTP-Telemetry-40D9C0?style=flat&labelColor=000000&logo=gov.uk)](https://confluence.tools.tax.service.gov.uk/display/TEL/Telemetry)

<!-- toc -->

- [Purpose](#purpose)
- [Updating the submodule](#updating-the-submodule)
  * [Pre-requisites](#pre-requisites)
  * [Example Usage](#example-usage)
- [Tools](#tools)

<!-- tocstop -->

This repository contains [cookiecutter](https://github.com/cookiecutter/cookiecutter) template resources for Telemetry AWS
Lambda repositories. Only long-term, common and stable files should be added, e.g. scripts or configurations that, when
the need to be changed, they can be changed in unison. It is worth noting that files in this template repository can be 
overridden in the repository using the templates. Simply add the file to a skip list defined in the `pyproject.toml` in
the lambda repo. 

```toml
[tool.cruft]
skip = [".bandit"]
```

## Linking the repository

The repository is meant to be used as a cookiecutter source inside the `telemetry-lambda-*` repos. To add the templates
to the consuming repository run the command below in the root.

```shell
poetry add --group dev cruft cookiecutter
cruft link https://github.com/hmrc/telemetry-lambda-resources
cruft update
```

## Updating the repository

```shell
cruft check
cruft diff
cruft update --skip-apply-as
```
## References

* [Cruft](https://cruft.github.io/cruft)
* [Cookiecutter](https://cookiecutter.readthedocs.io/en/stable/)

## License

This code is open source software licensed under the [Apache 2.0 License]("http://www.apache.org/licenses/LICENSE-2.0.html").
