SET search_path TO documentdb_core,documentdb_api,documentdb_api_catalog,documentdb_api_internal;

SET citus.next_shard_id TO 9630000;
SET documentdb.next_collection_id TO 963000;
SET documentdb.next_collection_index_id TO 963000;

-- Insert data
SELECT documentdb_api.insert_one('invmatch','airports','{ "_id": 1, "airport_id": 10165, "city": "Adak Island", "state": "AK", "name": "Adak", "rule": { "flight_type": "private"} }', NULL);
SELECT documentdb_api.insert_one('invmatch','airports','{ "_id": 3, "airport_id": 11308, "city": "Dothan", "state": "AL", "name": "Dothan Regional", "rule": { "$or": [ { "origin": "WA"}, {"flight_type": "private"}] } }', NULL);
SELECT documentdb_api.insert_one('invmatch','airports','{ "_id": 4, "airport_id": 11778, "city": "Fort Smith", "state": "AR", "name": "Fort Smith Regional", "rule": { "$in": [{"is_emergency": true}, {"is_vip": true}] }}', NULL);
SELECT documentdb_api.insert_one('invmatch','airports','{ "_id": 6, "airport_id": 14689, "city": "Santa Barbara", "state": "CA", "name": "Santa Barbara Municipal", "rule": { "$or": [ {"$and": [{"flight_type": "private"}, {"origin": "CA"}]}, {"$or": [{"is_emergency": true}, {"is_vip": true}]} ] }}', NULL);
SELECT documentdb_api.insert_one('invmatch','airports','{ "_id": 7, "airport_id": 13442, "city": "Everet", "state": "WA", "name": "Paine Field", "rule": { "tags": { "$all": ["private", "vip"]}}}', NULL);

-- positive cases
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{"$match": {"state": "AK"}}, { "$inverseMatch": {"path": "rule", "input": {"flight_type": "public"}}}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{"$match": {"state": "AK"}}, { "$inverseMatch": {"path": "rule", "input": {"flight_type": "private"}}}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{"$match": {"state": "AL"}}, { "$inverseMatch": {"path": "rule", "input": {"flight_type": "public"}}}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{"$match": {"state": "AL"}}, { "$inverseMatch": {"path": "rule", "input": {"flight_type": "private"}}}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{"$match": {"state": "AR"}}, { "$inverseMatch": {"path": "rule", "input": {"is_emergency": true}}}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{"$match": {"state": "CA"}}, { "$inverseMatch": {"path": "rule", "input": { "flight_type": "private", "origin": "CA" }}}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{"$match": {"state": "CA"}}, { "$inverseMatch": {"path": "rule", "input": { "flight_type": "public", "origin": "CA" }}}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{"$match": {"state": "CA"}}, { "$inverseMatch": {"path": "rule", "input": { "flight_type": "public", "origin": "CA", "is_vip": true }}}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{"$match": {"state": "AR"}}, { "$inverseMatch": {"path": "rule", "input": [{ "flight_type": "private"}, {"is_emergency": true}]}}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{"$match": {"state": "WA"}}, { "$inverseMatch": {"path": "rule", "input": { "tags": ["private", "vip"]}}}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{ "$inverseMatch": {"path": "rule", "input": { "origin": "WA" }}}]}');

-- Validate errors
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [ { "$inverseMatch": {"pathRule": "rule", "input": {"flight_type": "private"} }}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [ { "$inverseMatch": {"path": "rule", "inputValue": {"flight_type": "private"} }}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [ { "$inverseMatch": {"path": "", "input": {"flight_type": "private"} }}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [ { "$inverseMatch": {"path": "rule", "input": ["flight_type", "private"] }}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [ { "$inverseMatch": {"path": "rule", "input": [{"flight_type": "private"}, ""] }}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [ { "$inverseMatch": [{"path": "rule", "input": [{"flight_type": "private"}, ""] }, {"path": "rule2", "input": {}}]}]}');

-- insert a document with an invalid query
SELECT documentdb_api.insert_one('invmatch','airports','{ "_id": 8, "airport_id": 13442, "city": "Everet", "state": "WA", "name": "Paine Field", "specialRule": { "tags": { "$allValues": ["private", "vip"]}}}', NULL);

-- any inverseMatch that queries that path should fail
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{ "$inverseMatch": {"path": "specialRule", "input": { "origin": "WA" }, "defaultResult": false}}]}');

-- if we query "rule" path without defaultResult in the spec it should not match for the Everet airport which doesn't define the rule as the default value is false
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{ "$inverseMatch": {"path": "rule", "input": { "origin": "WA" }}}]}');

-- with defaultResult true should return all documents that don't define the path and false shouldn't return them
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{ "$inverseMatch": {"path": "rule", "input": { "origin": "WA" }, "defaultResult": true}}]}');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "airports", "pipeline": [{ "$inverseMatch": {"path": "rule", "input": { "origin": "WA" }, "defaultResult": false}}]}');


-- add tests with lookup for RBAC "like" scenarios
SELECT documentdb_api.insert_one('invmatch','user_roles','{ "_id": 1, "user_id": 100, "roles": ["basic"]}', NULL);
SELECT documentdb_api.insert_one('invmatch','user_roles','{ "_id": 2, "user_id": 101, "roles": ["basic", "sales"]}', NULL);
SELECT documentdb_api.insert_one('invmatch','user_roles','{ "_id": 3, "user_id": 102, "roles": ["admin"]}', NULL);

SELECT documentdb_api.insert_one('invmatch','sales','{ "_id": 1, "order": 100, "paid": true, "total": 0, "rule": {"roles": {"$in": ["basic", "sales", "admin"]}}}', NULL);
SELECT documentdb_api.insert_one('invmatch','sales','{ "_id": 2, "order": 102, "paid": true, "total": 1000, "rule": {"roles": {"$in": ["sales", "admin"]}}}', NULL);
SELECT documentdb_api.insert_one('invmatch','sales','{ "_id": 3, "order": 103, "paid": true, "total": 1000, "rule": {"roles": {"$in": ["admin"]}}}', NULL);

SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$lookup": { "from": "user_roles", "pipeline": [ { "$match": {"user_id": 100} } ], "as": "roles" }}, { "$inverseMatch": {"path": "rule", "input": "$roles"}}, {"$project": {"roles": 0, "rule": 0}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$lookup": { "from": "user_roles", "pipeline": [ { "$match": {"user_id": 101} } ], "as": "roles" }}, { "$inverseMatch": {"path": "rule", "input": "$roles"}}, {"$project": {"roles": 0, "rule": 0}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$lookup": { "from": "user_roles", "pipeline": [ { "$match": {"user_id": 102} } ], "as": "roles" }}, { "$inverseMatch": {"path": "rule", "input": "$roles"}}, {"$project": {"roles": 0, "rule": 0}} ], "cursor": {} }');

-- use from collection instead of lookup (new feature)
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 100}}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 101}}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 102}}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 102}}, {"$project": {"roles": 1, "_id": 0}}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": { "$lt": 102 }}}, {"$limit": 1}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": { "$ne": 200 }}}, {"$limit": 1}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": { "$lte": 102 }}}, {"$limit": 2}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": []}} ], "cursor": {} }');

EXPLAIN (COSTS OFF, VERBOSE ON) SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": { "$ne": 200 }}}, {"$limit": 1}]}} ], "cursor": {} }'); 
EXPLAIN (COSTS OFF, VERBOSE ON) SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": { "$ne": 200 }}}]}} ], "cursor": {} }'); 
EXPLAIN (COSTS OFF, VERBOSE ON) SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "input": {}}} ], "cursor": {} }'); 

-- test with sharded collections.
SELECT documentdb_api.shard_collection('invmatch', 'sales', '{"order": "hashed"}', false);
SELECT documentdb_api.shard_collection('invmatch', 'user_roles', '{"_id": "hashed"}', false);

SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$lookup": { "from": "user_roles", "pipeline": [ { "$match": {"user_id": 100} } ], "as": "roles" }}, { "$inverseMatch": {"path": "rule", "input": "$roles"}}, {"$project": {"roles": 0, "rule": 0}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$lookup": { "from": "user_roles", "pipeline": [ { "$match": {"user_id": 101} } ], "as": "roles" }}, { "$inverseMatch": {"path": "rule", "input": "$roles"}}, {"$project": {"roles": 0, "rule": 0}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$lookup": { "from": "user_roles", "pipeline": [ { "$match": {"user_id": 102} } ], "as": "roles" }}, { "$inverseMatch": {"path": "rule", "input": "$roles"}}, {"$project": {"roles": 0, "rule": 0}} ], "cursor": {} }');

-- use from collection instead of lookup (new feature)
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 100}}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 101}}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 102}}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 102}}, {"$project": {"roles": 1, "_id": 0}}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": { "$lt": 102 }}}, {"$limit": 1}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": { "$ne": 200 }}}, {"$limit": 1}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": { "$lte": 102 }}}, {"$limit": 2}]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": []}} ], "cursor": {} }');

-- drop and recreate so that it is not sharded and test with group and sort
SELECT documentdb_api.drop_database('invmatch');
SELECT documentdb_api.insert_one('invmatch','user_roles','{ "_id": 2, "user_id": 101, "role": "admin"}', NULL);
SELECT documentdb_api.insert_one('invmatch','user_roles','{ "_id": 1, "user_id": 100, "role": "basic"}', NULL);
SELECT documentdb_api.insert_one('invmatch','user_roles','{ "_id": 5, "user_id": 103, "role": "basic"}', NULL);
SELECT documentdb_api.insert_one('invmatch','user_roles','{ "_id": 3, "user_id": 102, "role": "sales"}', NULL);
SELECT documentdb_api.insert_one('invmatch','user_roles','{ "_id": 4, "user_id": 100, "role": "sales"}', NULL);
SELECT documentdb_api.insert_one('invmatch','user_roles','{ "_id": 6, "user_id": 102, "role": "admin"}', NULL);

SELECT documentdb_api.insert_one('invmatch','payments','{ "_id": 5, "order": 102, "order_total": 1000, "amount": 100, "rule": "admin"}', NULL);
SELECT documentdb_api.insert_one('invmatch','payments','{ "_id": 1, "order": 100, "order_total": 50, "amount": 20, "rule": "basic"}', NULL);
SELECT documentdb_api.insert_one('invmatch','payments','{ "_id": 2, "order": 102, "order_total": 1000, "amount": 300, "rule": "sales"}', NULL);
SELECT documentdb_api.insert_one('invmatch','payments','{ "_id": 4, "order": 100, "order_total": 50, "amount": 5, "rule": "basic"}', NULL);
SELECT documentdb_api.insert_one('invmatch','payments','{ "_id": 3, "order": 102, "order_total": 1000, "amount": 200, "rule": "basic"}', NULL);

SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "payments", "pipeline": [ {"$sort": {"order": 1}}, { "$group": { "_id": "$order", "ruleToCreate": {"$push": "$rule"}, "payed": {"$sum": "$amount"}}}, {"$project": {"rule": {"role": {"$arrayToObject": [[[{"$literal": "$in"}, "$ruleToCreate"]]]}}, "_id": 1, "payed": 1}}, {"$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": []}}], "cursor": {} }');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "payments", "pipeline": [ {"$sort": {"order": 1}}, { "$group": { "_id": "$order", "ruleToCreate": {"$push": "$rule"}, "payed": {"$sum": "$amount"}}}, {"$project": {"rule": {"role": {"$arrayToObject": [[[{"$literal": "$in"}, "$ruleToCreate"]]]}}, "_id": 1, "payed": 1}}, {"$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 102}}]}}], "cursor": {} }');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "payments", "pipeline": [ {"$sort": {"order": 1}}, { "$group": { "_id": "$order", "ruleToCreate": {"$push": "$rule"}, "payed": {"$sum": "$amount"}}}, {"$project": {"rule": {"role": {"$arrayToObject": [[[{"$literal": "$in"}, "$ruleToCreate"]]]}}, "_id": 1, "payed": 1}}, {"$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 100}}]}}], "cursor": {} }');

SELECT documentdb_api.drop_collection('invmatch', 'payments');

SELECT documentdb_api.insert_one('invmatch','payments','{ "_id": 5, "order": 102, "order_total": 1000, "amount": 100, "rule": { "role": "admin"}}', NULL);
SELECT documentdb_api.insert_one('invmatch','payments','{ "_id": 1, "order": 100, "order_total": 50, "amount": 20, "rule": { "role": "basic"}}', NULL);
SELECT documentdb_api.insert_one('invmatch','payments','{ "_id": 2, "order": 102, "order_total": 1000, "amount": 300, "rule": { "role": "sales"}}', NULL);
SELECT documentdb_api.insert_one('invmatch','payments','{ "_id": 4, "order": 100, "order_total": 50, "amount": 5, "rule": { "role": "basic"}}', NULL);
SELECT documentdb_api.insert_one('invmatch','payments','{ "_id": 3, "order": 102, "order_total": 1000, "amount": 200, "rule": { "role": "admin"}}', NULL);

SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "payments", "pipeline": [ { "$group": { "_id": "$order", "rule": {"$mergeObjects": "$rule"}, "payed": {"$sum": "$amount"}}}, {"$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 102}}]}}], "cursor": {} }');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "payments", "pipeline": [ { "$group": { "_id": "$order", "rule": {"$mergeObjects": "$rule"}, "payed": {"$sum": "$amount"}}}, {"$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": [{"$match": {"user_id": 100}}]}}], "cursor": {} }');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "payments", "pipeline": [ { "$group": { "_id": "$order", "rule": {"$mergeObjects": "$rule"}, "payed": {"$sum": "$amount"}}}, {"$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": []}}], "cursor": {} }');

SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "payments", "pipeline": [ {"$sort": {"order": 1}}, {"$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": []}}], "cursor": {} }');
SELECT document FROM bson_aggregation_pipeline('invmatch', '{ "aggregate": "payments", "pipeline": [ {"$sort": {"order": -1}}, {"$inverseMatch": {"path": "rule", "from": "user_roles", "pipeline": []}}], "cursor": {} }');

-- negative cases
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": {}, "input": "$roles"}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "", "input": "$roles"}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "input": [true]}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "input": true}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "input": {}, "from": "collection"}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "collection"}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"rule": "rule"}} ], "cursor": {} }');
SELECT document from bson_aggregation_pipeline('invmatch', '{ "aggregate": "sales", "pipeline": [ { "$inverseMatch": {"path": "rule", "from": "mycoll", "pipeline": []}} ], "cursor": {} }');
