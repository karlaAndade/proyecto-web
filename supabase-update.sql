-- Actualizar la tabla todos para las nuevas funciones
-- Ejecuta esto en tu panel de Supabase (SQL Editor)

-- Primero, eliminar la tabla existente si existe
DROP TABLE IF EXISTS todos;

-- Crear la tabla todos con todas las columnas nuevas
CREATE TABLE todos (
  id BIGSERIAL PRIMARY KEY,
  task TEXT NOT NULL,
  completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  category TEXT DEFAULT 'personal',
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  due_date DATE,
  notes TEXT
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;

-- Crear políticas para permitir todas las operaciones (para desarrollo)
CREATE POLICY "Enable read access for all users" ON todos FOR SELECT USING (true);
CREATE POLICY "Enable insert access for all users" ON todos FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update access for all users" ON todos FOR UPDATE USING (true);
CREATE POLICY "Enable delete access for all users" ON todos FOR DELETE USING (true);

-- Insertar algunos datos de ejemplo (opcional)
INSERT INTO todos (task, category, priority, due_date, notes) VALUES
('Completar proyecto de universidad', 'study', 'high', '2025-06-15', 'Revisar todos los capítulos antes de la entrega'),
('Comprar ingredientes para cena', 'shopping', 'medium', '2025-06-13', 'No olvidar el aceite de oliva'),
('Hacer ejercicio', 'health', 'medium', '2025-06-13', '30 minutos de cardio'),
('Llamar a mamá', 'family', 'low', '2025-06-14', 'Preguntarle sobre el cumpleaños del sábado'),
('Preparar presentación', 'work', 'high', '2025-06-14', 'Incluir gráficos y estadísticas actualizadas');
