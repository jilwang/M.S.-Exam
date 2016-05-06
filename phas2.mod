set cuts;
set cuts_non_converted;
set cuts_non_85;
set cuts_non_hotdog;
set cuts_combine_85;
set supweeks;
set weeks;
set subweeks;
set types;
set types_non_constraint;

param yield {cuts};

param primary_demand {cuts};
param primary_price {cuts};

param hotdog_demand;
param hotdog_price;
param hotdog_cost;

param processor_demand;
param processor_price;

param ground_minimum;
param ground_demand;
param ground_price;
param ground_cost;

param freeze_cost;
param discount;
param pallet_cap;

param weight_in_hotdog {cuts};

param purchase_cost;

var profit_primary {weeks};
var profit_ground {weeks};
var profit_bone_trim65 {weeks};
var profit_hotdog {weeks};
var profit_cost {weeks};

var load {weeks} integer >= 0;
var sold_fresh {cuts, weeks, types} >= 0;
var sold_store {cuts, weeks, types} >= 0;
var sold_total {cuts, weeks, types} >= 0;
var sold_hotdog {weeks} >= 0;

var storage {cuts, supweeks} >= 0;
var convert_input {cuts, weeks} >= 0;

var ground_binary {weeks} binary;
var freeze_pallet {weeks} integer >= 0;

var dump {cuts, weeks} >= 0;

maximize profit:
	sum {j in weeks} (profit_primary[j] + profit_ground[j] + profit_bone_trim65[j] + profit_hotdog[j] - profit_cost[j]);

# Constraint 1 - Profit decomposition
subject to profit_primary_def {j in weeks}:
	profit_primary[j] = sum {i in cuts} (sold_fresh[i, j, "primary"] + sold_store[i, j, "primary"] * discount) * primary_price[i];
	
subject to profit_ground_def {j in weeks}:
	profit_ground[j] = (sold_fresh["trim85", j, "secondary"] + sold_store["trim85", j, "secondary"] * discount) * ground_price;

subject to profit_bone_trim65_def {j in weeks}:
	profit_bone_trim65[j] = (sold_fresh["bone", j, "secondary"] + sold_fresh["trim65", j, "secondary"] 
				+ (sold_store["bone", j, "secondary"] + sold_store["trim65", j, "secondary"]) * discount) * processor_price;

subject to profit_hotdog_def {j in weeks}:
	profit_hotdog[j] = sold_hotdog[j] * hotdog_price;

subject to profit_cost_def {j in weeks}:
	profit_cost[j] = load[j] * purchase_cost
			+ freeze_pallet[j] * freeze_cost
			+ sold_total["trim85", j, "secondary"] * ground_cost
			+ sold_hotdog[j] * hotdog_cost;

# Constraint 2 - Balance of inlet/outlet
subject to Balance_week_j {i in cuts, j in weeks}:
	storage[i, j - 1] + convert_input[i, j] + load[j] * yield[i] 
		= sum {k in types} sold_total[i, j, k] + storage[i, j] + dump[i, j];

# Constraint 3 - Def of sold_total
subject to def_sold_total {i in cuts, j in weeks, k in types}:
	sold_total[i, j, k] = sold_fresh[i, j, k] + sold_store[i, j, k];

# Constraint 4 - Supply upper limit
subject to supply_fresh_cut {i in cuts, j in weeks}:
	sum {k in types} sold_fresh[i, j, k] <= load[j] * yield[i];

subject to supply_storage {i in cuts, j in weeks}:
	sum {k in types} sold_store[i, j, k] <= storage[i, j - 1];

# Constraint 5 - Demand upper limit
subject to demand_primary {i in cuts, j in weeks}:
	sold_total[i, j, "primary"] <= primary_demand[i];

subject to demand_ground {j in weeks}:
	sold_total["trim85", j, "secondary"] <= ground_demand;

subject to demand_proc {j in weeks}:
	sold_total["bone", j, "secondary"] + sold_total["trim65", j, "secondary"] <= processor_demand * load[j];

subject to demand_hotdog {j in weeks}:
	sold_hotdog[j] <= hotdog_demand;

# Constraint 6 - Trim 85 conversion:
subject to trim85_conversion_input {j in weeks}:
	convert_input["trim85", j] = sum {i in cuts} sold_total[i, j, "trim"];

subject to other_conversion_input {i in cuts_non_converted, j in weeks}:
	convert_input[i, j] = 0;

subject to blending_round_trim65 {j in weeks}:
	sold_total["round", j, "trim"] = 2 * sold_total["trim65", j, "trim"];

subject to non_trimmed {i in cuts_non_85, j in weeks}:
	sold_total[i, j, "trim"] = 0;
	
# Constraint 7 - Hotdog conversion:
subject to blend_to_hotdog {i in cuts, j in weeks}:
	sold_total[i, j, "hotdog"] = weight_in_hotdog[i] * sold_hotdog[j];

# Constraint 8 - Storage
subject to pallet_lower_bound {j in weeks}:
	sum {i in cuts} storage[i, j] <= pallet_cap * freeze_pallet[j];

subject to pallet_higher_bound {j in weeks}:
	sum {i in cuts} storage[i, j] >= pallet_cap * (freeze_pallet[j] - 1);

subject to cold_start {i in cuts}:
	storage[i, 0] = 0;

# Constraint 9 - Ground beef threshold:
subject to availability {j in weeks}:
	ground_minimum * ground_binary[j] <= convert_input["trim85", j] + load[j] * yield["trim85"]
				+ storage["trim85", j - 1] 
				- sum {k in types_non_constraint} sold_total["trim85", j, k]
				- storage["trim85", j] - dump["trim85", j];
				
subject to ground_minimum_limit {j in weeks}:
	sold_total["trim85", j, "secondary"] >= ground_minimum * ground_binary[j];

subject to ground_binary_upper {j in weeks}:
	sold_total["trim85", j, "secondary"] <= 1e7 * ground_binary[j];

