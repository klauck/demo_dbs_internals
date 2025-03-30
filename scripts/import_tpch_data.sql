\COPY part     FROM '/root/data/tpch_0.01/part.csv'     DELIMITER '|';
\COPY region   FROM '/root/data/tpch_0.01/region.csv'   DELIMITER '|';
\COPY nation   FROM '/root/data/tpch_0.01/nation.csv'   DELIMITER '|';
\COPY supplier FROM '/root/data/tpch_0.01/supplier.csv' DELIMITER '|';
\COPY partsupp FROM '/root/data/tpch_0.01/partsupp.csv' DELIMITER '|';
\COPY customer FROM '/root/data/tpch_0.01/customer.csv' DELIMITER '|';
\COPY orders   FROM '/root/data/tpch_0.01/orders.csv'   DELIMITER '|';
\COPY lineitem FROM '/root/data/tpch_0.01/lineitem.csv' DELIMITER '|';
ANALYZE;
