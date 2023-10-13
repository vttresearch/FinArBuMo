#=
    process_archetypes.jl

The main program file for Spine Toolbox.
=#

using Pkg
Pkg.activate(@__DIR__)
using FinnishArchetypeBuildingModel
import FinnishArchetypeBuildingModel.ArchetypeBuildingModel.load_definitions_template
m = Module()


## Parse command line arguments

if length(ARGS) < 6
    @error """
    `process_archetypes.jl` requires at least the following input arguments:
    1. `-datapackage* <filepath_to_data*>` filepaths pointing to the `datapackage.json` of used datasets.
    2. `-definitions <url_to_definitions>` the url to the Spine Datastore containing the archetype building definitions.

    The following optional keywords can be provided to tweak raw data processing:
    3. `-num_lids Inf`, number of `location_id` objects included in the resulting datastore (e.g. for testing).
    4. `-thermal_conductivity_weight 0.5`, how thermal conductivity of the materials is sampled. Average by default.
    5. `-interior_node_depth 0.1`, how deep the interior thermal node is positioned within the structure. Based on the calibrations performed in https://cris.vtt.fi/en/publications/sensitivity-of-a-simple-lumped-capacitance-building-thermal-model.
    6. `-variation_period 1209600`, "period of variations" as defined in EN ISO 13786:2017 Annex C, equal to two weeks in seconds. Based on the calibrations performed in https://cris.vtt.fi/en/publications/sensitivity-of-a-simple-lumped-capacitance-building-thermal-model.

    Furthermore, archetype building processing can be tweaked with the following optional keywords:
    7. `-spineopt <>`, the url to a Spine Datastore where the produced SpineOpt input data should be written.
    8. `-backbone <>`, the url to a Spine Datastore where the produced Backbone input data should be written.
    9. `-generic <>`, the url to a Spine Datastore where the produced Generic input data should be written.
    10. `-objects <>`, the url to a Spine Datastore where raw data objects are imported. Can be helpful for populating definitions.
    11. `-results <definitions>`, the url to a Spine Datastore where the baseline results are to be written. If not provided, results are written into the definitions url.
    12. `-weather <definitions>`, the url of the Spine Datastore into which the autogenerated weather data is imported. If not provided, weather data is written  into the definitions url.
    13. `-save_layouts <false>`, controls whether auto-generated `building_weather` layouts are saved as images.
    14. `-alternative <"">`, the name of the alternative where the parameters are saved, empty by default.
    15. `-realization <realization>`, The name of the stochastic scenario containing true data over forecasts, only relevant when generating stochastic forecast data.
    """
elseif !iseven(length(ARGS))
    @error """
    `process_archetypes.jl` input arguments need to be formatted in pairs, e.g.
    `-datapackage1 "<filepath_to_datapackage>"`
    """
else
    # Read keywords
    kws = Dict(ARGS[i] => get(ARGS, i + 1, nothing) for i in 1:2:length(ARGS))
    # Parse required keywords
    dp_paths = values(filter(r -> occursin("datapackage", r[1]), kws))
    def_url = get(kws, "-definitions", nothing)
    if length(dp_paths) < 2
        @error """
        `process_archetypes.jl` requires at least two datapackages as input:
        1. Datapackage containing statistical data about the Finnish building stock.
        2. Datapackage containing structural data about the Finnish building stock.

        These should be given as
        `-datapackage1 "<filepath_to_datapackage1>"`
        `-datapackage2 "<filepath_to_datapackage2>"`
        etc.
        """
    end
    if isnothing(def_url)
        @error """
        `process_archetypes.jl` requires a Spine Datastore URL
        for the archetype building definitions.

        This should be given as
        `-definitions "sqlite:///<filepath_to_sqlite>"`
        """
    end
    # Parse optional keywords
    num_lids = parse(Float64, get(kws, "-num_lids", "Inf"))
    tcw = parse(Float64, get(kws, "-thermal_conductivity_weight", "0.5"))
    ind = parse(Float64, get(kws, "-interior_node_depth", "0.1"))
    vp = parse(Float64, get(kws, "variation_period", "1209600"))
    spineopt_url = get(kws, "-spineopt", nothing)
    backbone_url = get(kws, "-backbone", nothing)
    generic_url = get(kws, "-generic", nothing)
    objects_url = get(kws, "-objects", nothing)
    results_url = get(kws, "-results", nothing)
    weather_url = get(kws, "-weather", nothing)
    save_layouts = parse(Bool, lowercase(get(kws, "-save_layouts", "false")))
    alternative = get(kws, "-alternative", "")
    realization = Symbol(get(kws, "-realization", "realization"))
end


## Read raw data and run tests

m = Module()
@time data = data_from_package(dp_paths...)
@info "Generating data convenience functions..."
@time using_spinedb(data, m)
@info "Running structural input data tests..."
@time run_structural_tests(; limit=Inf, mod=m)
@info "Running statistical input data tests..."
@time run_statistical_tests(; limit=Inf, mod=m)


## Import object classes relevant for `building_scope` definitions into <objects> url if defined.

if !isnothing(objects_url)
    @info "Importing definition-relevant object classes into `$(objects_url)`..."
    objclss = [:building_stock, :building_type, :heat_source, :location_id]
    @time import_data(
        objects_url,
        [m._spine_object_classes[oc] for oc in objclss],
        "Auto-import object classes relevant for archetype definitions."
    )
end


## Import and merge definitions

m = Module()
@time defs = data_from_url(def_url)
@info "Merge data and definitions..."
@time merge_data!(defs, data)
@info "Generating data and definitions convenience functions..."
@time using_spinedb(defs, m)


## Create, filter, and test processed statistics

@time create_processed_statistics!(m, num_lids, tcw, ind, vp)
archetype_template = load_definitions_template()
objclss = Symbol.(first.(archetype_template["object_classes"]))
relclss = Symbol.(first.(archetype_template["relationship_classes"]))
filter_module!(m; obj_classes=objclss, rel_classes=relclss)
@time run_input_data_tests(m)


## Process ScopeData and WeatherData, and create the ArchetypeBuildings

scope_data_dictionary, weather_data_dictionary, archetype_dictionary =
    archetype_building_processing(
        weather_url,
        save_layouts;
        realization=realization,
        mod=m
    )


## Heating/cooling demand calculations.

archetype_results_dictionary = solve_archetype_building_hvac_demand(
    archetype_dictionary;
    free_dynamics=false,
    realization=realization,
    mod=m
)


## Write the results into the desired datastore.

results__building_archetype__building_node,
results__building_archetype__building_process,
results__system_link_node = initialize_result_classes!(m)
add_results!(
    results__building_archetype__building_node,
    results__building_archetype__building_process,
    results__system_link_node,
    archetype_results_dictionary;
    mod=m
)
@info "Importing `ArchetypeBuildingResults` into `$(results_url)`..."
@time import_data(
    results_url,
    [
        results__building_archetype__building_node,
        results__building_archetype__building_process,
        results__system_link_node,
    ],
    "Importing `ArchetypeBuildingResults`.",
)


## Process input data if requested

for (input_url, name, input) in [
    (spineopt_url, "SpineOpt", SpineOptInput),
    (backbone_url, "Backbone", BackboneInput),
    (generic_url, "Generic", GenericInput),
]
    if !isnothing(input_url)
        @info "Processing and writing $(name) input data into `$(input_url)`..."
        @time write_to_url(
            String(input_url),
            input(archetype_results_dictionary; mod=m);
            alternative=alternative
        )
    end
end

@info """
All done!
You can access the `ArchetypeBuilding` data in the `archetype_dictionary`,
and the `ArchetypeBuildingResults` in the `archetype_results_dictionary`.
`ScopeData` and `WeatherData` are also available in the `scope_data_dictionary`
and `weather_data_dictionary` respectively.
"""