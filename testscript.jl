#=
    testscript.jl

A Julia script used for testing and development.
=#

using FinArBuMo
import FinArBuMo.ArBuMo.load_definitions_template

## Define required inputs

datapackage_paths = [
    "raw_data\\finnish_building_stock_forecasts\\datapackage.json",
    "raw_data\\finnish_RT_structural_data\\datapackage.json",
    "raw_data\\Finnish-building-stock-default-structural-data\\datapackage.json"
]
definitions_url = "sqlite:///C:\\_SPINEPROJECTS\\flexib_finnish_building_stock_validation_v08\\archetype_definitions.sqlite"
objects_url = definitions_url
weather_url = definitions_url
results_url = "sqlite:///C:\\_SPINEPROJECTS\\flexib_finnish_building_stock_validation_v08\\results.sqlite"

num_lids = Inf # Limit number of location ids to save time on test processing.
tcw = 0.5 # Thermal conductivity weight, average.
ind = 0.1 # Assumed interior node depth.
vp = 1209600.0 # Assumed period of variations for calculating effective thermal mass.
realization = :realization
save_layouts = true
renew_data = false


## Create hash from raw data settings to see if data already exists.

hsh = hash((num_lids, tcw, ind, vp))
filepath = "raw_data\\$(hsh).ser"
if !renew_data && isfile(filepath)
    # Use existing data if no flag and data exists.
    @warn "Using found existing processed data `$(filepath)`!"
else
    # Otherwise, process and test raw data anew.
    m = Module()
    @time data = data_from_package(datapackage_paths...)
    @info "Generating data convenience functions..."
    @time using_spinedb(data, m)
    @info "Running structural input data tests..."
    @time run_structural_tests(; limit=Inf, mod=m)
    @info "Running statistical input data tests..."
    @time run_statistical_tests(; limit=Inf, mod=m)
    @time create_processed_statistics!(m, num_lids, tcw, ind, vp)
    @info "Serialize and save processed data..."
    @time serialize_processed_data(m, hsh; filepath=filepath)

    # Import object classes relevant for `building_scope` definitions into <objects> url if defined.
    if !isnothing(objects_url)
        @info "Importing definition-relevant object classes into `$(objects_url)`..."
        objclss = [:building_stock, :building_type, :heat_source, :location_id]
        @time import_data(
            objects_url,
            [m._spine_object_classes[oc] for oc in objclss],
            "Auto-import object classes relevant for archetype definitions."
        )
    end
end
@info "Deserialize saved data..."
@time data = FinArBuMo.deserialize(filepath)


## Import, merge, and test definitions

m = Module()
@time defs = data_from_url(definitions_url)
@info "Merge data and definitions..."
@time merge_data!(defs, data)
@info "Generating data and definitions convenience functions..."
@time using_spinedb(defs, m)
@time run_input_data_tests(m)


## Process ScopeData and create the ArchetypeBuildings

scope_data_dictionary, archetype_dictionary = archetype_building_processing(
    m;
    save_layouts=save_layouts,
    realization=realization,
)


## Heating/cooling demand calculations.

archetype_results_dictionary = solve_archetype_building_hvac_demand(
    archetype_dictionary;
    mod=m,
    realization=realization,
)


## Write the results back into the input datastore

results__building_archetype,
results__building_archetype__building_node,
results__building_archetype__building_process,
results__system_link_node = initialize_result_classes!(m)
add_results!(
    results__building_archetype,
    results__building_archetype__building_node,
    results__building_archetype__building_process,
    results__system_link_node,
    archetype_results_dictionary;
    mod=m,
)
@info "Importing `ArchetypeBuildingResults` into `$(results_url)`..."
@time import_data(
    results_url,
    [
        results__building_archetype,
        results__building_archetype__building_node,
        results__building_archetype__building_process,
        results__system_link_node,
    ],
    "Importing `ArchetypeBuildingResults`.",
)