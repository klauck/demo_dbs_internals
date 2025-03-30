echo "Create TPC-H tables..."
docker exec -it demo_postgres psql -U postgres -d demo_db_internals -f /root/scripts/create_tpch_schema.sql
echo "done"

echo "Load TPC-H data..."
docker exec -it demo_postgres psql -U postgres -d demo_db_internals -f /root/scripts/import_tpch_data.sql
echo "done"