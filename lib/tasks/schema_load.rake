# Cargar el esquema (db:schema:load, y por tanto db:setup) recrea todas las tablas. Con SQLite y claves
# foráneas activas, eso falla si la base de datos ya tiene datos (por ejemplo, la de test después de
# ejecutar los tests). En desarrollo y test se vacía antes la base de datos, lo que no pierde nada que
# la carga del esquema no fuera a borrar igualmente.
Rake::Task["db:schema:load"].enhance([ "db:purge" ]) if Rails.env.local?
