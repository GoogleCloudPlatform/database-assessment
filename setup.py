# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import setuptools
from db_assessment.version import __version__

NAME = "oracle-db-assessment"
DESCRIPTION = (
    "A tool to enable collection of data from Oracle databases for "
    "homogeneous and heterogeneous database migration assessment"
)
VERSION = __version__
RELEASE_STATUS = "Development Status :: 4 - Beta"

with open("README.md", "r", encoding="UTF-8") as fh:
    long_description = fh.read()

dependencies = []
with open("requirements/base.txt", "r", encoding="UTF-8") as fp:
    for line in fp.readlines():
        if not line.strip().startswith("#"):
            dependencies.append(line.strip())

extras_require = {}

packages = setuptools.find_packages(include=["db_assessment"])

setuptools.setup(
    name=NAME,
    description=DESCRIPTION,
    version=VERSION,
    author="Eri Santos",
    author_email="erisantos@google.com",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/GoogleCloudPlatform/oracle-database-assessment",
    packages=packages,
    classifiers=[
        RELEASE_STATUS,
        "License :: OSI Approved :: Apache Software License",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.8",
    install_requires=dependencies,
    extras_require=extras_require,
    entry_points={
        "console_scripts": [
            "opdba = db_assessment.optimusprime:main",
            "optimus-prime = db_assessment.optimusprime:main",
        ],
    },
)
