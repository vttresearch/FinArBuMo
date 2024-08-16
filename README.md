# FinArBuMo

A Finland-specific application of [ArBuMo](https://github.com/vttresearch/ArBuMo).

The goal of this module is to integrate the Julia workflows of
[FinnishBuildingStockData](https://github.com/vttresearch/FinnishBuildingStockData)
and [ArBuMo](https://github.com/vttresearch/ArBuMo),
in order to reduce the required computational time.

>[!IMPORTANT]
>2024-08-16: The *FlexiB* project funding this research is ending, making it unlikely that this module will receive see further active development.


## Installation

In order to follow the installation steps below, you need to have the following
software installed on your computer and in your `PATH`:
1. [Git](https://www.git-scm.com/)
2. [Julia](https://julialang.org/)

Since this package is not indexed in online package repositories,
you need to download or clone this repository onto your machine.
E.g. using Git: 
```
git clone <url_of_the_repository> <path_to_FinArBuMo>
```
Similarly, since [FinnishBuildingStockData](https://github.com/vttresearch/FinnishBuildingStockData)
and [ArBuMo](https://github.com/vttresearch/ArBuMo)
aren't indexed in online repositories, their source needs to be downloaded or cloned
onto your machine:
```
git clone "https://github.com/vttresearch/FinnishBuildingStockData.git" <path_to_FinnishBuildingStockData>
git clone "https://github.com/vttresearch/ArBuMo.git" <path_to_ArBuMo>
```

Once you have these repositories on your machine,
navigate into this root folder *(the one containing this `README.md`)*.
Then, open Julia REPL to install the dependencies:
```julia
using Pkg
Pkg.activate(".")
Pkg.develop("<path_to_FinnishBuildingStockData>")
Pkg.develop("<path_to_ArBuMo>")
```
You might also need to install the dependencies of
[FinnishBuildingStockData](https://github.com/vttresearch/FinnishBuildingStockData)
and [ArBuMo](https://github.com/vttresearch/ArBuMo)
by running
```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```
in their respective root folders.


## Usage

TBD


## Documentation

This README is all you're getting at the moment, I'm afraid.


## License

[MIT](https://mit-license.org/), see `LICENSE` for details.


## How to cite

TBD


## Acknowledgements

<center>
<table width=500px frame="none">
<tr>
<td valign="middle" width=100px>
<img src=https://www.aka.fi/globalassets/aka_en_vaaka_valkoinen.svg alt="AKA emblem" width=100%></td>
<td valign="middle">
This module was built for the Research Council of Finland project "Integration of building flexibility into future energy systems (FlexiB)" under grant agreement No 332421.
</td>
</table>
</center>
