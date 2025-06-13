<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { supabase } from './supabaseClient'

interface Todo {
  id: number
  task: string
  completed: boolean
  created_at: string
  category: string
  priority: 'low' | 'medium' | 'high'
  due_date: string | null
  notes: string | null
}

const todos = ref<Todo[]>([])
const newTask = ref('')
const newCategory = ref('personal')
const newPriority = ref<'low' | 'medium' | 'high'>('medium')
const newDueDate = ref('')
const newNotes = ref('')
const loading = ref(false)
const searchQuery = ref('')
const selectedFilter = ref('all')
const selectedCategory = ref('all')
const selectedPriority = ref('all')
const darkMode = ref(true)
const editingTodo = ref<number | null>(null)
const editText = ref('')

const categories = [
  { value: 'personal', label: '👤 Personal', color: '#4ecdc4' },
  { value: 'work', label: '💼 Trabajo', color: '#45b7d1' },
  { value: 'health', label: '🏃 Salud', color: '#96ceb4' },
  { value: 'shopping', label: '🛒 Compras', color: '#ffeaa7' },
  { value: 'study', label: '📚 Estudio', color: '#dda0dd' },
  { value: 'family', label: '👨‍👩‍👧‍👦 Familia', color: '#ff7675' }
]

const priorities = [
  { value: 'low', label: 'Baja', color: '#74b9ff' },
  { value: 'medium', label: 'Media', color: '#fdcb6e' },
  { value: 'high', label: 'Alta', color: '#e17055' }
]

// Computed properties
const filteredTodos = computed(() => {
  let filtered = todos.value

  // Filtrar por búsqueda
  if (searchQuery.value) {
    filtered = filtered.filter(todo => 
      todo.task.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
      (todo.notes && todo.notes.toLowerCase().includes(searchQuery.value.toLowerCase()))
    )
  }

  // Filtrar por estado
  if (selectedFilter.value === 'pending') {
    filtered = filtered.filter(todo => !todo.completed)
  } else if (selectedFilter.value === 'completed') {
    filtered = filtered.filter(todo => todo.completed)
  } else if (selectedFilter.value === 'overdue') {
    const today = new Date().toISOString().split('T')[0]
    filtered = filtered.filter(todo => 
      !todo.completed && todo.due_date && todo.due_date < today
    )
  }

  // Filtrar por categoría
  if (selectedCategory.value !== 'all') {
    filtered = filtered.filter(todo => todo.category === selectedCategory.value)
  }

  // Filtrar por prioridad
  if (selectedPriority.value !== 'all') {
    filtered = filtered.filter(todo => todo.priority === selectedPriority.value)
  }

  return filtered.sort((a, b) => {
    // Ordenar por prioridad y fecha
    const priorityOrder = { high: 3, medium: 2, low: 1 }
    if (priorityOrder[a.priority] !== priorityOrder[b.priority]) {
      return priorityOrder[b.priority] - priorityOrder[a.priority]
    }
    return new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  })
})

const completionPercentage = computed(() => {
  if (todos.value.length === 0) return 0
  return Math.round((todos.value.filter(t => t.completed).length / todos.value.length) * 100)
})

const todayTasks = computed(() => {
  const today = new Date().toISOString().split('T')[0]
  return todos.value.filter(todo => todo.due_date === today)
})

const overdueTasks = computed(() => {
  const today = new Date().toISOString().split('T')[0]
  return todos.value.filter(todo => 
    !todo.completed && todo.due_date && todo.due_date < today
  )
})

// Cargar todos al montar el componente
onMounted(async () => {
  await fetchTodos()
  // Cargar preferencia de tema
  const savedTheme = localStorage.getItem('darkMode')
  if (savedTheme) {
    darkMode.value = JSON.parse(savedTheme)
  }
})

// Obtener todos de Supabase
const fetchTodos = async () => {
  loading.value = true
  try {
    const { data, error } = await supabase
      .from('todos')
      .select('*')
      .order('created_at', { ascending: false })
    
    if (error) {
      console.error('Error fetching todos:', error)
    } else {
      todos.value = data || []
    }
  } catch (error) {
    console.error('Error:', error)
  } finally {
    loading.value = false
  }
}

// Agregar nueva tarea
const addTodo = async () => {
  if (!newTask.value.trim()) return
  
  try {
    const todoData = {
      task: newTask.value.trim(),
      completed: false,
      category: newCategory.value,
      priority: newPriority.value,
      due_date: newDueDate.value || null,
      notes: newNotes.value.trim() || null
    }

    const { data, error } = await supabase
      .from('todos')
      .insert([todoData])
      .select()
    
    if (error) {
      console.error('Error adding todo:', error)
    } else {
      todos.value.unshift(data[0])
      resetForm()
    }
  } catch (error) {
    console.error('Error:', error)
  }
}

// Resetear formulario
const resetForm = () => {
  newTask.value = ''
  newCategory.value = 'personal'
  newPriority.value = 'medium'
  newDueDate.value = ''
  newNotes.value = ''
}

// Alternar estado completado
const toggleTodo = async (todo: Todo) => {
  try {
    const { error } = await supabase
      .from('todos')
      .update({ completed: !todo.completed })
      .eq('id', todo.id)
    
    if (error) {
      console.error('Error updating todo:', error)
    } else {
      todo.completed = !todo.completed
    }
  } catch (error) {
    console.error('Error:', error)
  }
}

// Eliminar tarea
const deleteTodo = async (id: number) => {
  try {
    const { error } = await supabase
      .from('todos')
      .delete()
      .eq('id', id)
    
    if (error) {
      console.error('Error deleting todo:', error)
    } else {
      todos.value = todos.value.filter(todo => todo.id !== id)
    }
  } catch (error) {
    console.error('Error:', error)
  }
}

// Editar tarea
const startEdit = (todo: Todo) => {
  editingTodo.value = todo.id
  editText.value = todo.task
}

const saveEdit = async () => {
  if (!editingTodo.value || !editText.value.trim()) return
  
  try {
    const { error } = await supabase
      .from('todos')
      .update({ task: editText.value.trim() })
      .eq('id', editingTodo.value)
    
    if (error) {
      console.error('Error updating todo:', error)
    } else {
      const todo = todos.value.find(t => t.id === editingTodo.value)
      if (todo) {
        todo.task = editText.value.trim()
      }
      cancelEdit()
    }
  } catch (error) {
    console.error('Error:', error)
  }
}

const cancelEdit = () => {
  editingTodo.value = null
  editText.value = ''
}

// Alternar modo oscuro
const toggleDarkMode = () => {
  darkMode.value = !darkMode.value
  localStorage.setItem('darkMode', JSON.stringify(darkMode.value))
}

// Exportar datos
const exportTodos = () => {
  const dataStr = JSON.stringify(todos.value, null, 2)
  const dataUri = 'data:application/json;charset=utf-8,'+ encodeURIComponent(dataStr)
  
  const exportFileDefaultName = `todos-${new Date().toISOString().split('T')[0]}.json`
  
  const linkElement = document.createElement('a')
  linkElement.setAttribute('href', dataUri)
  linkElement.setAttribute('download', exportFileDefaultName)
  linkElement.click()
}

// Limpiar completadas
const clearCompleted = async () => {
  const completedIds = todos.value.filter(t => t.completed).map(t => t.id)
  
  try {
    const { error } = await supabase
      .from('todos')
      .delete()
      .in('id', completedIds)
    
    if (error) {
      console.error('Error clearing completed:', error)
    } else {
      todos.value = todos.value.filter(t => !t.completed)
    }
  } catch (error) {
    console.error('Error:', error)
  }
}

// Obtener color de categoría
const getCategoryColor = (category: string) => {
  return categories.find(c => c.value === category)?.color || '#4ecdc4'
}

// Obtener color de prioridad
const getPriorityColor = (priority: string) => {
  return priorities.find(p => p.value === priority)?.color || '#fdcb6e'
}

// Verificar si una tarea está vencida
const isOverdue = (todo: Todo) => {
  if (!todo.due_date || todo.completed) return false
  const today = new Date().toISOString().split('T')[0]
  return todo.due_date < today
}

// Formatear fecha
const formatDate = (dateString: string) => {
  const date = new Date(dateString)
  return date.toLocaleDateString('es-ES', { 
    day: 'numeric', 
    month: 'short' 
  })
}
</script>

<template>
  <div class="app" :class="{ 'dark-mode': darkMode, 'light-mode': !darkMode }">
    <div class="container">
      <!-- Header con controles -->
      <header class="header">
        <div class="header-top">
          <h1 class="title">
            <span class="emoji">✨</span>
            Mis tareas
            <span class="emoji">✨</span>
          </h1>
          <div class="header-controls">
            <button @click="toggleDarkMode" class="theme-toggle">
              <span v-if="darkMode">🌙</span>
              <span v-else>☀️</span>
            </button>
            <button @click="exportTodos" class="export-btn" title="Exportar tareas">
              📥
            </button>
            <button 
              @click="clearCompleted" 
              class="clear-btn" 
              title="Limpiar completadas"
              :disabled="!todos.some(t => t.completed)"
            >
              🗑️
            </button>
          </div>
        </div>
        <p class="subtitle">Organiza tu vida con estilo y eficiencia</p>
        
        <!-- Barra de progreso -->
        <div class="progress-section">
          <div class="progress-info">
            <span>Progreso general: {{ completionPercentage }}%</span>
            <span class="task-count">{{ todos.filter(t => t.completed).length }}/{{ todos.length }}</span>
          </div>
          <div class="progress-bar">
            <div 
              class="progress-fill" 
              :style="{ width: completionPercentage + '%' }"
            ></div>
          </div>
        </div>
      </header>

      <!-- Alertas -->
      <div v-if="overdueTasks.length > 0" class="alert alert-danger">
        ⚠️ Tienes {{ overdueTasks.length }} tarea(s) vencida(s)
      </div>
      <div v-if="todayTasks.length > 0" class="alert alert-info">
        📅 Tienes {{ todayTasks.length }} tarea(s) para hoy
      </div>

      <!-- Estadísticas generales -->
      <div v-if="todos.length > 0" class="stats-grid stats-top">
        <div class="stat-card">
          <div class="stat-number">{{ todos.filter(t => !t.completed).length }}</div>
          <div class="stat-label">Pendientes</div>
        </div>
        <div class="stat-card">
          <div class="stat-number">{{ todos.filter(t => t.completed).length }}</div>
          <div class="stat-label">Completadas</div>
        </div>
        <div class="stat-card">
          <div class="stat-number">{{ overdueTasks.length }}</div>
          <div class="stat-label">Vencidas</div>
        </div>
        <div class="stat-card">
          <div class="stat-number">{{ todayTasks.length }}</div>
          <div class="stat-label">Para Hoy</div>
        </div>
      </div>

      <!-- Formulario avanzado para agregar tareas -->
      <div class="add-todo-section">
        <div class="form-grid">
          <div class="input-group">
            <input
              v-model="newTask"
              @keyup.enter="addTodo"
              type="text"
              placeholder="¿Qué necesitas hacer?"
              class="todo-input main-input"
            />
          </div>
          
          <div class="form-row">
            <div class="input-group">
              <label>Categoría</label>
              <select v-model="newCategory" class="select-input">
                <option v-for="cat in categories" :key="cat.value" :value="cat.value">
                  {{ cat.label }}
                </option>
              </select>
            </div>
            
            <div class="input-group">
              <label>Prioridad</label>
              <select v-model="newPriority" class="select-input">
                <option v-for="priority in priorities" :key="priority.value" :value="priority.value">
                  {{ priority.label }}
                </option>
              </select>
            </div>
            
            <div class="input-group">
              <label>Fecha límite</label>
              <input v-model="newDueDate" type="date" class="date-input" />
            </div>
          </div>
          
          <div class="input-group">
            <textarea
              v-model="newNotes"
              placeholder="Notas adicionales (opcional)"
              class="notes-input"
              rows="2"
            ></textarea>
          </div>
        </div>
        
        <button @click="addTodo" class="add-btn-large" :disabled="!newTask.trim()">
          <span class="plus-icon">+</span>
          Agregar Tarea
        </button>
      </div>

      <!-- Controles de filtrado -->
      <div class="filters-section">
        <div class="search-bar">
          <input
            v-model="searchQuery"
            type="text"
            placeholder="🔍 Buscar tareas..."
            class="search-input"
          />
        </div>
        
        <div class="filter-controls">
          <div class="filter-group">
            <label>Estado:</label>
            <select v-model="selectedFilter" class="filter-select">
              <option value="all">Todas</option>
              <option value="pending">Pendientes</option>
              <option value="completed">Completadas</option>
              <option value="overdue">Vencidas</option>
            </select>
          </div>
          
          <div class="filter-group">
            <label>Categoría:</label>
            <select v-model="selectedCategory" class="filter-select">
              <option value="all">Todas</option>
              <option v-for="cat in categories" :key="cat.value" :value="cat.value">
                {{ cat.label }}
              </option>
            </select>
          </div>
          
          <div class="filter-group">
            <label>Prioridad:</label>
            <select v-model="selectedPriority" class="filter-select">
              <option value="all">Todas</option>
              <option v-for="priority in priorities" :key="priority.value" :value="priority.value">
                {{ priority.label }}
              </option>
            </select>
          </div>
        </div>
      </div>

      <!-- Loading -->
      <div v-if="loading" class="loading">
        <div class="spinner"></div>
        <p>Cargando tareas...</p>
      </div>

      <!-- Lista de tareas mejorada -->
      <div v-else class="todo-list">
        <div
          v-for="todo in filteredTodos"
          :key="todo.id"
          class="todo-item advanced"
          :class="{ 
            completed: todo.completed, 
            overdue: isOverdue(todo),
            editing: editingTodo === todo.id
          }"
        >
          <div class="todo-main">
            <div class="todo-left">
              <div class="checkbox" :class="{ checked: todo.completed }" @click="toggleTodo(todo)">
                <svg v-if="todo.completed" class="check-icon" viewBox="0 0 24 24">
                  <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/>
                </svg>
              </div>
              
              <div class="todo-content">
                <div v-if="editingTodo === todo.id" class="edit-mode">
                  <input
                    v-model="editText"
                    @keyup.enter="saveEdit"
                    @keyup.escape="cancelEdit"
                    class="edit-input"
                    ref="editInput"
                  />
                  <div class="edit-actions">
                    <button @click="saveEdit" class="save-btn">✓</button>
                    <button @click="cancelEdit" class="cancel-btn">✕</button>
                  </div>
                </div>
                
                <div v-else class="todo-info">
                  <div class="todo-text" @dblclick="startEdit(todo)">
                    {{ todo.task }}
                  </div>
                  <div v-if="todo.notes" class="todo-notes">
                    {{ todo.notes }}
                  </div>
                </div>
              </div>
            </div>
            
            <div class="todo-right">
              <div class="todo-meta">
                <span 
                  class="category-badge" 
                  :style="{ backgroundColor: getCategoryColor(todo.category) }"
                >
                  {{ categories.find(c => c.value === todo.category)?.label.split(' ')[1] }}
                </span>
                <span 
                  class="priority-badge" 
                  :class="`priority-${todo.priority}`"
                  :style="{ borderColor: getPriorityColor(todo.priority) }"
                >
                  {{ priorities.find(p => p.value === todo.priority)?.label }}
                </span>
                <span v-if="todo.due_date" class="due-date" :class="{ overdue: isOverdue(todo) }">
                  📅 {{ formatDate(todo.due_date) }}
                </span>
              </div>
              
              <div class="todo-actions">
                <button @click="startEdit(todo)" class="edit-btn" title="Editar">
                  ✏️
                </button>
                <button @click="deleteTodo(todo.id)" class="delete-btn" title="Eliminar">
                  🗑️
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Estado vacío -->
        <div v-if="filteredTodos.length === 0 && !loading" class="empty-state">
          <div class="empty-icon">
            <span v-if="searchQuery || selectedFilter !== 'all'">🔍</span>
            <span v-else>📝</span>
          </div>
          <h3 v-if="searchQuery || selectedFilter !== 'all'">
            No se encontraron tareas
          </h3>
          <h3 v-else>¡Comienza a organizar tu día!</h3>
          <p v-if="searchQuery || selectedFilter !== 'all'">
            Intenta cambiar los filtros o la búsqueda
          </p>
          <p v-else>
            Agrega tu primera tarea para comenzar
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.app {
  min-height: 100vh;
  transition: all 0.3s ease;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
}

.dark-mode {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.light-mode {
  background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%);
  color: #2d3748;
}

.container {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

.header {
  text-align: center;
  margin-bottom: 40px;
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.title {
  font-size: 3rem;
  font-weight: 800;
  margin: 0;
  text-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
}

.emoji {
  font-size: 2rem;
  margin: 0 10px;
}

.subtitle {
  font-size: 1.1rem;
  margin: 10px 0 20px 0;
  font-weight: 300;
  opacity: 0.9;
}

.header-controls {
  display: flex;
  gap: 10px;
}

.theme-toggle, .export-btn, .clear-btn {
  width: 45px;
  height: 45px;
  border-radius: 50%;
  border: none;
  font-size: 1.2rem;
  cursor: pointer;
  transition: all 0.3s ease;
}

.dark-mode .theme-toggle, 
.dark-mode .export-btn, 
.dark-mode .clear-btn {
  background: rgba(255, 255, 255, 0.1);
  color: white;
}

.light-mode .theme-toggle, 
.light-mode .export-btn, 
.light-mode .clear-btn {
  background: rgba(0, 0, 0, 0.1);
  color: #2d3748;
}

.theme-toggle:hover, .export-btn:hover, .clear-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
}

.progress-section {
  margin-top: 20px;
}

.progress-info {
  display: flex;
  justify-content: space-between;
  margin-bottom: 10px;
  font-size: 0.9rem;
  opacity: 0.9;
}

.progress-bar {
  height: 8px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 10px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #4ecdc4, #44a08d);
  border-radius: 10px;
  transition: width 0.5s ease;
}

.alert {
  padding: 15px;
  border-radius: 12px;
  margin-bottom: 20px;
  font-weight: 500;
}

.alert-danger {
  background: rgba(231, 76, 60, 0.2);
  border-left: 4px solid #e74c3c;
}

.alert-info {
  background: rgba(52, 152, 219, 0.2);
  border-left: 4px solid #3498db;
}

.add-todo-section {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-radius: 20px;
  padding: 25px;
  margin-bottom: 30px;
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.form-grid {
  display: flex;
  flex-direction: column;
  gap: 20px;
  margin-bottom: 20px;
}

.form-row {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 15px;
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.input-group label {
  font-size: 0.9rem;
  font-weight: 500;
  opacity: 0.9;
}

.main-input {
  padding: 15px 20px;
  font-size: 1.1rem;
}

.todo-input, .select-input, .date-input, .notes-input {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 12px;
  padding: 12px 16px;
  color: inherit;
  font-size: 1rem;
  transition: all 0.3s ease;
}

.todo-input:focus, .select-input:focus, .date-input:focus, .notes-input:focus {
  outline: none;
  border-color: rgba(255, 255, 255, 0.6);
  box-shadow: 0 0 0 3px rgba(255, 255, 255, 0.1);
}

.todo-input::placeholder, .notes-input::placeholder {
  opacity: 0.7;
}

.notes-input {
  resize: vertical;
  min-height: 60px;
}

.add-btn-large {
  background: linear-gradient(135deg, #ff6b6b, #ee5a24);
  border: none;
  padding: 15px 30px;
  border-radius: 50px;
  color: white;
  font-size: 1.1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  width: 100%;
  box-shadow: 0 4px 15px rgba(238, 90, 36, 0.3);
}

.add-btn-large:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(238, 90, 36, 0.4);
}

.add-btn-large:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.plus-icon {
  font-size: 1.3rem;
}

.filters-section {
  margin-bottom: 30px;
}

.search-bar {
  margin-bottom: 20px;
}

.search-input {
  width: 100%;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 25px;
  padding: 15px 20px;
  color: inherit;
  font-size: 1rem;
  transition: all 0.3s ease;
}

.search-input:focus {
  outline: none;
  border-color: rgba(255, 255, 255, 0.6);
  box-shadow: 0 0 0 3px rgba(255, 255, 255, 0.1);
}

.search-input::placeholder {
  opacity: 0.7;
}

.filter-controls {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 15px;
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.filter-group label {
  font-size: 0.9rem;
  font-weight: 500;
  opacity: 0.9;
}

.filter-select {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 8px;
  padding: 10px 12px;
  color: inherit;
  font-size: 0.9rem;
}

.loading {
  text-align: center;
  padding: 40px;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid rgba(255, 255, 255, 0.3);
  border-top: 3px solid white;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin: 0 auto 20px;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.todo-list {
  margin-top: 15px;
}

.todo-item.advanced {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-radius: 16px;
  padding: 20px;
  margin-bottom: 15px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
  transition: all 0.3s ease;
}

.todo-item.advanced:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
}

.todo-item.completed {
  opacity: 0.7;
}

.todo-item.overdue {
  border-left: 4px solid #e74c3c;
}

.todo-main {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 15px;
}

.todo-left {
  display: flex;
  align-items: flex-start;
  gap: 15px;
  flex: 1;
}

.checkbox {
  width: 24px;
  height: 24px;
  border: 2px solid rgba(255, 255, 255, 0.5);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.3s ease;
  flex-shrink: 0;
  margin-top: 2px;
}

.checkbox.checked {
  background: linear-gradient(135deg, #4ecdc4, #44a08d);
  border-color: #4ecdc4;
}

.check-icon {
  width: 14px;
  height: 14px;
  fill: white;
}

.todo-content {
  flex: 1;
}

.edit-mode {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.edit-input {
  background: rgba(255, 255, 255, 0.2);
  border: 1px solid rgba(255, 255, 255, 0.4);
  border-radius: 8px;
  padding: 8px 12px;
  color: inherit;
  font-size: 1rem;
}

.edit-actions {
  display: flex;
  gap: 5px;
}

.save-btn, .cancel-btn {
  width: 30px;
  height: 30px;
  border: none;
  border-radius: 50%;
  cursor: pointer;
  font-size: 0.9rem;
  transition: all 0.3s ease;
}

.save-btn {
  background: #4ecdc4;
  color: white;
}

.cancel-btn {
  background: #e74c3c;
  color: white;
}

.todo-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.todo-text {
  font-size: 1rem;
  font-weight: 500;
  line-height: 1.4;
  cursor: pointer;
  transition: all 0.3s ease;
}

.todo-item.completed .todo-text {
  text-decoration: line-through;
  opacity: 0.6;
}

.todo-notes {
  font-size: 0.9rem;
  opacity: 0.8;
  font-style: italic;
  line-height: 1.3;
}

.todo-right {
  display: flex;
  flex-direction: column;
  gap: 10px;
  align-items: flex-end;
}

.todo-meta {
  display: flex;
  flex-direction: column;
  gap: 5px;
  align-items: flex-end;
}

.category-badge, .priority-badge, .due-date {
  font-size: 0.8rem;
  padding: 4px 8px;
  border-radius: 12px;
  font-weight: 500;
}

.category-badge {
  color: white;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
}

.priority-badge {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid;
  backdrop-filter: blur(5px);
}

.due-date {
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.3);
}

.due-date.overdue {
  background: rgba(231, 76, 60, 0.2);
  border-color: #e74c3c;
  color: #e74c3c;
}

.todo-actions {
  display: flex;
  gap: 5px;
}

.edit-btn, .delete-btn {
  width: 35px;
  height: 35px;
  border: none;
  border-radius: 50%;
  cursor: pointer;
  font-size: 0.9rem;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.edit-btn {
  background: rgba(255, 193, 7, 0.2);
  color: #ffc107;
}

.delete-btn {
  background: rgba(220, 53, 69, 0.2);
  color: #dc3545;
}

.edit-btn:hover, .delete-btn:hover {
  transform: scale(1.1);
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
}

.empty-icon {
  font-size: 4rem;
  margin-bottom: 20px;
}

.empty-state h3 {
  font-size: 1.5rem;
  font-weight: 600;
  margin: 0 0 10px 0;
}

.empty-state p {
  opacity: 0.8;
  font-weight: 300;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 15px;
  margin-top: 30px;
}

.stats-top {
  margin-top: 40px;
  margin-bottom: 40px;
}

.stat-card {
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border-radius: 16px;
  padding: 20px;
  text-align: center;
  border: 1px solid rgba(255, 255, 255, 0.2);
  transition: all 0.3s ease;
}

.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
}

.stat-number {
  display: block;
  font-size: 2rem;
  font-weight: 700;
  margin-bottom: 5px;
}

.stat-label {
  font-size: 0.9rem;
  opacity: 0.8;
  font-weight: 400;
}

@media (max-width: 768px) {
  .app {
    padding: 15px;
  }
  
  .title {
    font-size: 2.5rem;
  }
  
  .container {
    max-width: 100%;
    padding: 15px;
  }
  
  .form-row {
    grid-template-columns: 1fr;
  }
  
  .filter-controls {
    grid-template-columns: 1fr;
  }
  
  .stats-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .todo-main {
    flex-direction: column;
    gap: 15px;
  }
  
  .todo-meta {
    align-items: flex-start;
  }
}
</style>
