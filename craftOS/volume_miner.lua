-- ======================================================================
-- MINADOR DE VOLUMEN 3D (3D Volume Miner)
-- ======================================================================
-- Este script permite a una tortuga de ComputerCraft excavar un volumen
-- tridimensional de dimensiones X (Ancho), Y (Alto) y Z (Largo).
--
-- INSTRUCCIONES DE COLOCACIÓN:
-- 1. Coloca la tortuga en la esquina INFERIOR-IZQUIERDA-FRONTAL del área.
-- 2. Coloca un cofre justo detrás de la tortuga (para descarga de ítems).
-- 3. Provee combustible (carbón, etc.) en la tortuga o en el cofre.
-- 4. La tortuga excavará:
--    * Z (Largo): hacia ADELANTE (su dirección inicial).
--    * X (Ancho): hacia la DERECHA.
--    * Y (Alto): hacia ARRIBA.
-- ======================================================================

-- ======================================================================
-- CONFIGURACIÓN GLOBAL (Modificable)
-- ======================================================================
-- Opción A: Modifica esta cadena de texto "AnchoXAltoXLargo" (ej: "30x30x30")
DIMENSIONES = "30x30x30"

-- Opción B: O define las variables numéricas directamente (deben ser > 0 para usarse)
X = nil
Y = nil
Z = nil
-- ======================================================================

-- Posicionamiento y orientación absoluta de la tortuga
local currX, currY, currZ = 1, 1, 1
local currDir = 0 -- 0 = Adelante (+Z), 1 = Derecha (+X), 2 = Atrás (-Z), 3 = Izquierda (-X)

-- Función para parsear las dimensiones configuradas
local function parseDimensions()
    local xVal, yVal, zVal
    
    -- Si se definen variables globales individuales numéricas, tienen prioridad
    if type(X) == "number" and type(Y) == "number" and type(Z) == "number" then
        xVal, yVal, zVal = X, Y, Z
    elseif type(DIMENSIONES) == "string" then
        -- Parsear formatos como "30x30x30", "30X30X30", "30,30,30" o "30 30 30"
        local pattern = "(%d+)[xX,%s]+(%d+)[xX,%s]+(%d+)"
        local xs, ys, zs = DIMENSIONES:match(pattern)
        if xs and ys and zs then
            xVal = tonumber(xs)
            yVal = tonumber(ys)
            zVal = tonumber(zs)
        end
    end
    
    -- Valores por defecto en caso de error o valores inválidos
    if not xVal or xVal <= 0 then xVal = 30 end
    if not yVal or yVal <= 0 then yVal = 30 end
    if not zVal or zVal <= 0 then zVal = 30 end
    
    return xVal, yVal, zVal
end

-- ======================================================================
-- SISTEMA DE MOVIMIENTO Y SEGUIMIENTO DE COORDENADAS
-- ======================================================================

local function turnLeft()
    turtle.turnLeft()
    currDir = (currDir - 1 + 4) % 4
end

local function turnRight()
    turtle.turnRight()
    currDir = (currDir + 1) % 4
end

local function turnTo(targetDir)
    while currDir ~= targetDir do
        local diff = (targetDir - currDir + 4) % 4
        if diff == 3 then
            turnLeft()
        else
            turnRight()
        end
    end
end

-- Funciones robustas de movimiento (rompen bloques y atacan si algo obstruye)
local function moveForward()
    local attempts = 0
    while not turtle.forward() do
        if turtle.detect() then
            turtle.dig()
        else
            turtle.attack()
            attempts = attempts + 1
            if attempts > 50 then
                print("Error: ¡Movimiento obstruido por un bloque indestructible o bedrock!")
                return false
            end
            sleep(0.1)
        end
    end
    
    -- Actualizar posición basándose en la dirección actual
    if currDir == 0 then
        currZ = currZ + 1
    elseif currDir == 1 then
        currX = currX + 1
    elseif currDir == 2 then
        currZ = currZ - 1
    elseif currDir == 3 then
        currX = currX - 1
    end
    return true
end

local function moveUp()
    local attempts = 0
    while not turtle.up() do
        if turtle.detectUp() then
            turtle.digUp()
        else
            turtle.attackUp()
            attempts = attempts + 1
            if attempts > 50 then
                print("Error: Obstruido hacia arriba.")
                return false
            end
            sleep(0.1)
        end
    end
    currY = currY + 1
    return true
end

local function moveDown()
    local attempts = 0
    while not turtle.down() do
        if turtle.detectDown() then
            turtle.digDown()
        else
            turtle.attackDown()
            attempts = attempts + 1
            if attempts > 50 then
                print("Error: Obstruido hacia abajo.")
                return false
            end
            sleep(0.1)
        end
    end
    currY = currY - 1
    return true
end

-- ======================================================================
-- GESTIÓN DE INVENTARIO Y COMBUSTIBLE
-- ======================================================================

-- Calcula el combustible necesario para volver a casa a (1,1,1) desde la posición actual más un margen
local function getRequiredFuel()
    if turtle.getFuelLevel() == "unlimited" then return 0 end
    local distance = (currX - 1) + (currY - 1) + (currZ - 1)
    return distance + 30 -- Distancia + 30 movimientos de seguridad
end

-- Verifica si el combustible es suficiente; intenta repostar si es necesario
local function checkFuel()
    if turtle.getFuelLevel() == "unlimited" then return true end
    
    -- Intentar reabastecerse desde el inventario si el nivel es bajo
    if turtle.getFuelLevel() < getRequiredFuel() + 100 then
        for i = 1, 16 do
            turtle.select(i)
            local item = turtle.getItemDetail()
            if item and (item.name == "minecraft:coal" or item.name == "minecraft:charcoal" or item.name == "minecraft:coal_block") then
                turtle.refuel()
            end
        end
        turtle.select(1)
    end
    
    -- Retorna true si tiene suficiente combustible para regresar de forma segura
    return turtle.getFuelLevel() >= getRequiredFuel()
end

-- Comprueba si el inventario de la tortuga está lleno (sin espacios vacíos)
local function isInventoryFull()
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            return false
        end
    end
    return true
end

-- Comprueba si se debe abortar y regresar por inventario lleno o combustible bajo
local function shouldAbort()
    if isInventoryFull() then
        print("¡Inventario lleno!")
        return true
    end
    if not checkFuel() then
        print("¡Combustible bajo!")
        return true
    end
    return false
end

-- Regresa de forma segura a (1,1,1) a través del espacio ya minado
local function goHome()
    print("Regresando a la base de inicio (1, 1, 1)...")
    
    -- 1. Regresar en Z al inicio
    turnTo(2) -- Mirar hacia atrás (-Z)
    while currZ > 1 do
        if not moveForward() then return false end
    end
    
    -- 2. Regresar en X al inicio
    turnTo(3) -- Mirar hacia la izquierda (-X)
    while currX > 1 do
        if not moveForward() then return false end
    end
    
    -- 3. Regresar en Y al inicio
    while currY > 1 do
        if not moveDown() then return false end
    end
    
    -- 4. Reorientarse hacia adelante (0)
    turnTo(0)
    return true
end

-- Descarga los ítems en el cofre detrás e intenta repostar combustible
local function dischargeAndRefuel()
    print("Descargando ítems en el cofre trasero...")
    
    -- Girar para mirar hacia atrás (-Z / Dirección 2) hacia el cofre
    turnTo(2)
    
    -- 1. Repostar primero usando cualquier combustible del inventario para optimizar espacio
    for i = 1, 16 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        if item and (item.name == "minecraft:coal" or item.name == "minecraft:charcoal" or item.name == "minecraft:coal_block") then
            turtle.refuel()
        end
    end
    
    -- 2. Vaciar todo lo demás al cofre
    for i = 1, 16 do
        turtle.select(i)
        if turtle.getItemCount(i) > 0 then
            if not turtle.drop() then
                print("¡Atención! Es posible que el cofre de descarga esté lleno.")
            end
        end
    end
    
    turtle.select(1)
    
    -- 3. Si el nivel de combustible sigue siendo bajo, intentar tomar del cofre
    if turtle.getFuelLevel() ~= "unlimited" and turtle.getFuelLevel() < getRequiredFuel() + 100 then
        print("Buscando carbón de soporte en el cofre...")
        while turtle.getFuelLevel() < getRequiredFuel() + 150 do
            if turtle.suck() then
                local item = turtle.getItemDetail()
                if item and (item.name == "minecraft:coal" or item.name == "minecraft:charcoal" or item.name == "minecraft:coal_block") then
                    turtle.refuel()
                else
                    turtle.drop() -- Devolver lo que no sea combustible
                    break
                end
            else
                break -- Cofre vacío o sin ítems
            end
        end
    end
    
    -- Volver a orientarse hacia el frente
    turnTo(0)
    print("Descarga e intento de repostaje completados.")
end

-- Vuelve a la posición del último bloque minado usando el camino ya excavado
local function resumeMining(targetX, targetY, targetZ, targetDir)
    print(string.format("Retornando al punto de trabajo (%d, %d, %d)...", targetX, targetY, targetZ))
    
    -- 1. Subir al nivel del target
    while currY < targetY do
        if not moveUp() then return false end
    end
    
    -- 2. Moverse en X
    turnTo(1) -- Mirar a la derecha (+X)
    while currX < targetX do
        if not moveForward() then return false end
    end
    
    -- 3. Moverse en Z
    turnTo(0) -- Mirar al frente (+Z)
    while currZ < targetZ do
        if not moveForward() then return false end
    end
    
    -- 4. Reorientarse a la dirección original
    turnTo(targetDir)
    print("¡Listo para continuar con la tarea!")
    return true
end

-- ======================================================================
-- PASOS INDIVIDUALES DE MINADO CON MANEJO DE RETORNO
-- ======================================================================

local function handleAbortAndResume()
    local savedX, savedY, savedZ, savedDir = currX, currY, currZ, currDir
    if not goHome() then
        print("¡Error crítico al intentar regresar a casa!")
        return false
    end
    
    dischargeAndRefuel()
    
    -- Bucle de espera si la tortuga sigue sin suficiente combustible
    while not checkFuel() do
        print("Esperando combustible... Coloque combustible en el cofre trasero o en el inventario.")
        sleep(5)
        
        -- Intentar repostar si se agregó combustible al inventario
        for i = 1, 16 do
            turtle.select(i)
            local item = turtle.getItemDetail()
            if item and (item.name == "minecraft:coal" or item.name == "minecraft:charcoal" or item.name == "minecraft:coal_block") then
                turtle.refuel()
            end
        end
        
        -- Intentar succionar del cofre trasero
        turnTo(2)
        if turtle.suck() then
            local item = turtle.getItemDetail()
            if item and (item.name == "minecraft:coal" or item.name == "minecraft:charcoal" or item.name == "minecraft:coal_block") then
                turtle.refuel()
            else
                turtle.drop()
            end
        end
        turnTo(0)
    end
    
    if not resumeMining(savedX, savedY, savedZ, savedDir) then
        print("¡Error al retornar a la posición de minado!")
        return false
    end
    return true
end

local function stepForward()
    if shouldAbort() then
        if not handleAbortAndResume() then return false end
    end
    
    if turtle.detect() then
        turtle.dig()
    end
    return moveForward()
end

local function stepUp()
    if shouldAbort() then
        if not handleAbortAndResume() then return false end
    end
    
    if turtle.detectUp() then
        turtle.digUp()
    end
    return moveUp()
end

-- ======================================================================
-- BUCLE PRINCIPAL DE EXCAVACIÓN (Lawnmower en 3D)
-- ======================================================================

local function main()
    local XVal, YVal, ZVal = parseDimensions()
    local totalBlocks = XVal * YVal * ZVal
    local volumeStep = 0
    
    -- Comprobación inicial de combustible
    if not checkFuel() then
        print("Repostando inicialmente desde inventario...")
        for i = 1, 16 do
            turtle.select(i)
            local item = turtle.getItemDetail()
            if item and (item.name == "minecraft:coal" or item.name == "minecraft:charcoal" or item.name == "minecraft:coal_block") then
                turtle.refuel()
            end
        end
        turtle.select(1)
        if not checkFuel() then
            print("Error: Combustible insuficiente para iniciar la tarea.")
            print("Coloque combustible en el cofre trasero o en la tortuga.")
            return
        end
    end
    
    print(string.format("Iniciando excavación de volumen: %dx%dx%d (%d bloques)", XVal, YVal, ZVal, totalBlocks))
    
    for y = 1, YVal do
        print(string.format("--- Iniciando Capa %d de %d ---", y, YVal))
        
        for x = 1, XVal do
            -- Columna impar: avanzar de z = 1 a ZVal (hacia adelante)
            if x % 2 == 1 then
                for z = 1, ZVal do
                    volumeStep = volumeStep + 1
                    if z > 1 then
                        if not stepForward() then
                            print("Error al avanzar.")
                            return
                        end
                    end
                    
                    -- Reporte de progreso cada 10 bloques o al final
                    if volumeStep % 10 == 0 or volumeStep == totalBlocks then
                        local percent = math.floor((volumeStep / totalBlocks) * 100)
                        print(string.format("Progreso: %d%% (%d/%d)", percent, volumeStep, totalBlocks))
                    end
                end
                
                -- Desplazamiento a la siguiente columna (derecha) si no es la última
                if x < XVal then
                    turnRight()
                    if not stepForward() then
                        print("Error al cambiar de columna.")
                        return
                    end
                    turnRight()
                end
                
            -- Columna par: retroceder de z = ZVal a 1
            else
                for z = ZVal, 1, -1 do
                    volumeStep = volumeStep + 1
                    if z < ZVal then
                        if not stepForward() then
                            print("Error al avanzar.")
                            return
                        end
                    end
                    
                    if volumeStep % 10 == 0 or volumeStep == totalBlocks then
                        local percent = math.floor((volumeStep / totalBlocks) * 100)
                        print(string.format("Progreso: %d%% (%d/%d)", percent, volumeStep, totalBlocks))
                    end
                end
                
                -- Desplazamiento a la siguiente columna (derecha) si no es la última
                if x < XVal then
                    turnLeft()
                    if not stepForward() then
                        print("Error al cambiar de columna.")
                        return
                    end
                    turnLeft()
                end
            end
        end
        
        -- Al final de la capa: volver al origen (1, y, 1) antes de subir
        if y < YVal then
            print("Capa completada. Retornando al inicio de la capa...")
            
            -- Regresar en Z a 1
            if currZ > 1 then
                turnTo(2)
                while currZ > 1 do
                    if not moveForward() then
                        print("Error regresando en Z al final de la capa.")
                        return
                    end
                end
            end
            
            -- Regresar en X a 1
            if currX > 1 then
                turnTo(3)
                while currX > 1 do
                    if not moveForward() then
                        print("Error regresando en X al final de la capa.")
                        return
                    end
                end
            end
            
            -- Mirar hacia el frente
            turnTo(0)
            
            -- Subir un nivel
            if not stepUp() then
                print("Error al subir a la siguiente capa.")
                return
            end
        end
    end
    
    -- Excavación terminada con éxito
    print("¡Excavación del volumen terminada!")
    goHome()
    dischargeAndRefuel()
    print("Programa finalizado. Tortuga en posición de reposo.")
end

main()
