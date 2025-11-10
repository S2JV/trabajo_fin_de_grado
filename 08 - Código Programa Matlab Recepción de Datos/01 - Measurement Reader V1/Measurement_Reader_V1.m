% ========================================================================
% Autor: Sebastián Jesús Jiménez Vázquez
% ========================================================================
% Escuela Superior de Ingeniería, Universidad de Cádiz (UCA)
% Graphical Methods, Optimization and Learning Research Group (GOAL)
% Trabajo Fin de Grado: Diseño y Fabricacion de un Instrumento de Medición
% de Consumo Eléctrico para Telfonía Móvil
% ========================================================================
% Nombre: Measurement Reader 
% Versión: 1.0
% Fecha: 12 de agosto de 2025
% ========================================================================
% Descripción: programa asociado al hardware diseñado en el trabajo fin de
% grado para la lectura, gestión y procesamiento de los datos obtenidos
% como resultado de la medición del consumo eléctrico en dispositivos
% móviles.
% ========================================================================

function Measurement_Reader_V1()
    
    % Borramos todo lo que pueda quedar de ejecuciones anteriores.
    clear all;      % Borra todas las variables del workspace.
    close all;      % Cierra todas los elementos y figuras abiertas
    clc;            % Limpia la Command Window.

    % Creamos la figura principal, inicialmente invisible hasta que esté
    % completa para evitar problemas gráficos
    fig = uifigure('Visible', 'off');

    % Creamos la estructura que contendrá las variables y los componentes
    % de la interfaz gráfica
    handles = struct();
    
    % Almacenamos el handle de la figura principal
    handles.fig = fig;
    
    % Creamos el listado desplegable de baudrates
    handles.config.BAUD_RATES = {'50',
                                '75',
                                '110',
                                '134',
                                '150',
                                '200',
                                '300',
                                '600',
                                '1200',
                                '1800',
                                '2400',
                                '4800',
                                '9600',
                                '19200',
                                '28800',
                                '38400',
                                '57600',
                                '76800',
                                '115200',
                                '230400',
                                '460800',
                                '576000',
                                '921600'};
    
    % Seleccionamos el baudrate por defecto
    handles.config.DEFAULT_BAUD_RATE = '460800';
    
    % Generamos el nombre del fichero usado para el csv donde se almacenen
    % los datos
    timestamp = datetime('now', 'Format', 'ddMMyy_HHmmss');
    handles.config.NOMBRE_FICHERO = "read_data_" + string(timestamp) + ".csv";
    
    % Parámetros de la UART
    handles.config.SYNC_BYTE = uint8(170);          % Byte de sincronización (0xAA)
    handles.config.MUESTRAS_POR_BLOQUE = 1000;      % Número de muestras a leer en cada bloque
    %handles.config.CONSTANTE_VATIOS = 915.6e-6;    % Constante para la conversión a vatios
    handles.config.CONSTANTE_VATIOS = 1.22e-3;      % Para solo voltaje
    %handles.config.CONSTANTE_VATIOS = 732e-6;      % Para solo corriente

    % Otras variables
    handles.state.device = [];                  % Objeto del puerto serie.
    handles.state.fileID = [];                  % Identificador del fichero csv de salida.
    handles.state.comPort = '';                 % Puerto COM seleccionado
    handles.state.baudRate = 0;                 % Baudrate seleccionado
    handles.state.stopRequest = false;          % Flag para detener el bucle de adquisición.
    
    % Construcción de la interfaz gráfica
    guidata(fig, handles);  % Almacena la estructura 'handles' en la figura para que sea accesible globalmente.
    populateGUI(fig);       % Llama a la función que crea y posiciona los elementos
    fig.Visible = 'on';     % Hacemos visible la interfaz

end

% -------------------------------------------------------------------------

% ========================================================================
% populateGUI
% Crea y posiciona todos los elementos que conforman la interfaz gráfica
% ========================================================================

function populateGUI(fig)

    % Cargamos la estructura handle desde fig
    handles = guidata(fig);

    % Definimos las propiedades de la ventana principal
    handles.fig.Name = 'Measurement Reader - Sebastián Jesús Jiménez Vázquez';  % Nombre de la ventana generada
    handles.fig.Position = [100 100 470 400];                                   % Posición y tamaño [x, y, ancho, alto].
    handles.fig.CloseRequestFcn = @(src,event) closeApp(src);                   % Asigna la función de cierre a la 'X' de la ventana.
    handles.fig.KeyPressFcn = @keyPressCallback;                                % Asigna la función que captura las pulsaciones del teclado

    % Definimos la Interfaz I
    % Etiqueta superior
    handles.lblStatus = uilabel(handles.fig, 'Position', [20 360 430 22], ...
        'Text', 'Bienvenido a Measurement Reader', 'FontSize', 14, 'FontWeight', 'bold');

    % Área de texto para mostrar logs y mensajes.
    handles.logTextArea = uitextarea(handles.fig, 'Position', [20 110 430 240], ...
        'Value', {'Bienvenido a Measurement Reader. Por favor, inicie el proceso de configuración.'}, 'Editable', 'off');
    
    % Coordenada Y para alinear los elementos de configuración.
    configY = 70; 

    % Definimos la configuración del COM
    uilabel(handles.fig, 'Text', 'Puerto COM:', 'Position', [30 configY 80 22]);

    handles.editCom = uieditfield(handles.fig, 'text', 'Position', ...
        [115 configY 100 22], 'Enable', 'off', 'HorizontalAlignment', 'left');
    
    % Definimos la configuración del Baudrate
    uilabel(handles.fig, 'Text', 'Baudrate:', 'Position', [240 configY 70 22]);

    handles.editBaud = uidropdown(handles.fig, 'Position', ...
        [315 configY 100 22], 'Items', handles.config.BAUD_RATES, 'Value', ...
        handles.config.DEFAULT_BAUD_RATE, 'Enable', 'off');

    % Definición del botón de acción
    buttonWidth = 170;                                      % Ancho del botón
    buttonX = (handles.fig.Position(3) - buttonWidth) / 2;  % Centramos el botón en el eje X
    buttonY = 20;                                           % Posición en el eje Y
    
    % Definimos los diferentes botones. Inicialmente se muestra solo el primero
    handles.btnSetup = uibutton(handles.fig, 'Text', 'Iniciar Configuración', ...
        'Position', [buttonX buttonY buttonWidth 30], 'FontSize', 14, 'ButtonPushedFcn', @setupConfiguration);

    handles.btnSaveConfig = uibutton(handles.fig, 'Text', 'Guardar Configuración', ...
        'Position', [buttonX buttonY buttonWidth 30], 'FontSize', 14, 'ButtonPushedFcn', @saveConfiguration, 'Visible', 'off');

    handles.btnStart = uibutton(handles.fig, 'Text', 'Iniciar Adquisición', ...
        'Position', [buttonX buttonY buttonWidth 30], 'FontSize', 14, 'ButtonPushedFcn', @startAcquisition, 'Visible', 'off');

    handles.btnStop = uibutton(handles.fig, 'Text', 'Parar Adquisición', ...
        'Position', [buttonX buttonY buttonWidth 30], 'FontSize', 14, 'ButtonPushedFcn', @stopAcquisition, 'Visible', 'off');

    handles.btnClose = uibutton(handles.fig, 'Text', 'Cerrar', ...
        'Position', [buttonX buttonY buttonWidth 30], 'FontSize', 14, 'ButtonPushedFcn', @closeApp, 'Visible', 'off');

    % Guarda la estructura handle en la figura
    guidata(handles.fig, handles);

end

% -------------------------------------------------------------------------

% ========================================================================
% keyPressCallback
% Cuando se pulsa una tecla en la ventana, se comprueba si el enter para
% usarlo como atajo de presionar el botón
% ========================================================================

function keyPressCallback(src, event)

    % Recuperamos los handles
    handles = guidata(src); 
    
    % Comprueba si la tecla pulsada fue 'Enter' (código 'return').
    if(strcmp(event.Key, 'return'))

        % Simula el clic del botón que esté visible y activo en ese momento.
        if(handles.btnSetup.Visible == 'on' && handles.btnSetup.Enable == 'on')
            setupConfiguration(handles.btnSetup, event);
        elseif(handles.btnSaveConfig.Visible == 'on' && handles.btnSaveConfig.Enable == 'on')
            saveConfiguration(handles.btnSaveConfig, event);
        elseif(handles.btnStart.Visible == 'on' && handles.btnStart.Enable == 'on')
            startAcquisition(handles.btnStart, event);
        elseif(handles.btnStop.Visible == 'on' && handles.btnStop.Enable == 'on')
            stopAcquisition(handles.btnStop, event);
        elseif(handles.btnClose.Visible == 'on' && handles.btnClose.Enable == 'on')
            closeApp(handles.btnClose);
        end

    end

end

% -------------------------------------------------------------------------

% ========================================================================
% setupConfiguration
% Gestiona el proceso de configuración de la herramienta
% ========================================================================

function setupConfiguration(src, event)

    handles = guidata(src); 
    handles.lblStatus.Text = 'Por favor, introduzca los parámetros.';
    
    % Muestra instrucciones en el log.
    logMessage(src, ' ');
    logMessage(src, '-- Instrucciones del Proceso de Configuración -------------------------------------------');
    logMessage(src, ' ');
    logMessage(src, '   1. Puerto COM: Utilice el siguiente formato: COMXX. Ejemplo: COM8.');
    logMessage(src, '   2. Baudrate: Seleccione el baudrate correspondiente. Asegurese que este coincide con el del dispositivo medidor.');
    
    % Habilita los campos de edición.
    handles.editCom.Enable = 'on';
    handles.editBaud.Enable = 'on';
    
    % Cambia los botones visibles.
    handles.btnSetup.Visible = 'off';
    handles.btnSaveConfig.Visible = 'on';
    
    % Pone el foco del cursor en el campo del Puerto COM.
    focus(handles.editCom);
    guidata(src, handles); 

end

% -------------------------------------------------------------------------

% ========================================================================
% saveConfiguration
% Gestiona el proceso de guardado de la configuración seleccionada
% ========================================================================

function saveConfiguration(src, event)

    handles = guidata(src);
    
    % Lee los valores seleccionados por el usuario para el COM y para el
    % Baudrate
    handles.state.comPort = string(handles.editCom.Value);
    handles.state.baudRate = str2double(handles.editBaud.Value);
    
    % Comprobamos que los campos no esten vacíos o que estos sean inválidos
    if(isempty(handles.state.comPort) || isnan(handles.state.baudRate) || handles.state.baudRate <= 0)
        logMessage(src, ' ');
        logMessage(src, '>> Error - Compruebe que los datos introducidos sean correctos'); return;
    end

    % Comprobamos que el formato del puerto COM es correcto
    if(isempty(regexp(handles.state.comPort, '^COM\d+$', 'once')))
        logMessage(src, ' ');
        logMessage(src, '>> ERROR - Compruebe el formato del puerto COM. Ejemplo: COM8'); return;
    end
    
    logMessage(src, ' ');
    logMessage(src, sprintf('Configuración guardada - Puerto COM: %s - Baudrate: %d baudios', ...
        handles.state.comPort, handles.state.baudRate));

    logMessage(src, ' ');
    handles.lblStatus.Text = 'Proceso de configuración finalizado. Listo para iniciar el proceso de adquisición de datos.';
    
    % Deshabilita los campos de edición y cambia los botones para la
    % siguiente pantalla
    handles.editCom.Enable = 'off';
    handles.editBaud.Enable = 'off';
    handles.btnSaveConfig.Visible = 'off';
    handles.btnStart.Visible = 'on';
    
    % Devuelve el foco a la ventana principal para que el 'Enter' siga funcionando.
    focus(handles.fig);
    guidata(src, handles);

end

% -------------------------------------------------------------------------

% ========================================================================
% startAcquisition
% Establece la conexión con la Zynq e inicia la adquisición de los datos
% ========================================================================

function startAcquisition(src, event)

    handles = guidata(src);
    handles.btnStart.Enable = 'off';
    logMessage(src, ' ');
    handles.lblStatus.Text = 'Iniciando adquisición de datos...';
    
    try
        % 1. Abrimos el puerto serie
        handles.state.device = serialport(handles.state.comPort, handles.state.baudRate, ...
            "ByteOrder", "little-endian", "Timeout", 10);
        
        % 2. Crear y abrir el fichero CSV
        logMessage(src, sprintf('Fichero de salida: %s', handles.config.NOMBRE_FICHERO));
        handles.state.fileID = fopen(handles.config.NOMBRE_FICHERO, 'w');
        fprintf(handles.state.fileID, 'Tiempo_s,Valor\n'); 
        
        % 3. Sincronizar con el dispositivo.
        logMessage(src, ' ');
        logMessage(src, 'Sincronizando el proceso de adquisición de datos con la Zynq...');
            
            % Limpiar buffer de entrada.
            flush(handles.state.device);                                                    

            % Esperar al byte de sync.
            while(read(handles.state.device, 1, "uint8") ~= handles.config.SYNC_BYTE)
            end

            % Descartar la primera muestra por precaución
            read(handles.state.device, 1, "uint16"); 
            logMessage(src, 'Sincronización establecida correctamente.');
            logMessage(src, ' ');
            logMessage(src, 'Proceso de adquisición de datos iniciado.');
        
        % 4. Actualizar GUI y entrar en el bucle de adquisición.
        handles.lblStatus.Text = 'Adquisición iniciada...';
        
            % Cambiamos los botones visibles
            handles.btnStart.Visible = 'off';
            handles.btnStop.Visible = 'on';
            
            guidata(src, handles);
        
            % Entramos en el bucle de adquisición de datos
            acquisitionLoop(src);
    
    % Bloque que se ejecuta si algo falla
    catch ME 
        logMessage(src, '>> ERROR - No se ha podido conectar al dispositivo ');
        logMessage(src, ' ');
        logMessage(src, ME.message);
        handles.lblStatus.Text = 'Error. Cierre la aplicación.';
        handles.btnStart.Visible = 'off';
        handles.btnStop.Visible = 'off';
        handles.btnClose.Visible = 'on';
        guidata(src, handles);
        return;
    end

end

% -------------------------------------------------------------------------

% ========================================================================
% acquisitionLoop
% Bucle encargado de la adquisición de datos. Estos son leidos, procesados
% y guardados.
% ========================================================================

function acquisitionLoop(src)

    handles = guidata(src);
    handles.state.stopRequest = false;
    guidata(src, handles);
    
    % Cálculo de constantes y variables
    bytes_por_muestra = 3; % SYNC + LSB + MSB
    bytes_por_bloque = handles.config.MUESTRAS_POR_BLOQUE * bytes_por_muestra;
    contador_total_muestras = 0;
    tiempo_base_bloque = 0;

    % Iniciamos el cronómetro
    tic;
    
    % El bucle se ejecuta mientras no se solicite parar el proceso y la ventana sea válida
    while(~handles.state.stopRequest && isvalid(handles.fig))

        % Comprueba si hay suficientes bytes en el buffer para leer un bloque completo
        if(handles.state.device.NumBytesAvailable >= bytes_por_bloque)
            tiempo_bloque_leido = toc; % Captura el tiempo actual
            
            % Lee el bloque de datos en raw
            data_chunk = read(handles.state.device, bytes_por_bloque, "uint8");
            
            % Reconstruimos las muestras 
            indices_sync = find(data_chunk == handles.config.SYNC_BYTE);
            num_muestras_en_bloque = length(indices_sync);
            datos_reconstruidos = zeros(num_muestras_en_bloque, 1, 'uint16');
            
            for(i = 1:num_muestras_en_bloque)
                idx = indices_sync(i);
                if((idx + 2) <= length(data_chunk))
                    % Reconstrucción del LSB
                    lsb = uint16(data_chunk(idx + 1));
                    
                    % Reconstrucción del MSB
                    msb = uint16(data_chunk(idx + 2));

                    % Reconstrucción del dato completo
                    datos_reconstruidos(i) = bitshift(msb, 8) + lsb; 
                end
            end
            
            % Generación de timestamps y guardado en fichero
            duracion_bloque = tiempo_bloque_leido - tiempo_base_bloque;
            paso_de_tiempo = duracion_bloque / num_muestras_en_bloque;
            timestamps_bloque = (tiempo_base_bloque + paso_de_tiempo * (1:num_muestras_en_bloque)');
            bloque_para_guardar = [timestamps_bloque, double(datos_reconstruidos)];
            fprintf(handles.state.fileID, '%.6f,%d\n', bloque_para_guardar');
            
            contador_total_muestras = contador_total_muestras + num_muestras_en_bloque;
            tiempo_base_bloque = tiempo_bloque_leido;

        else
            pause(0.001); % Pequeña pausa para no saturar la CPU
        end

        drawnow('limitrate');   % Actualiza la interfaz
        handles = guidata(src); % Recarga los handles para comprobar el flag de stop
    end
    
    % Al salir del bucle, guarda el resumen generado
    handles = guidata(src);
    handles.resumen_final.tiempo_total = toc;
    handles.resumen_final.muestras_totales = contador_total_muestras;
    guidata(src, handles);
    
    % Inicia el flujo de finalización
    cleanup(src, 'acquisition_finished');
    processData(src);
    transitionToFinalState(src);
    
end

% -------------------------------------------------------------------------

% ========================================================================
% processData
% Una vez finalizada la lectura de los datos se realiza un
% post-procesamiento de los datos para que puedan ser interpretados por el
% usuario
% ========================================================================

function processData(src)

    handles = guidata(src);
    
    logMessage(src, ' ');
    logMessage(src, '-- Post-Procesado de datos -----------------------------------------------------');
    handles.lblStatus.Text = 'Procesando datos. Por favor, espere...';
    
    try
        % 1. Lee el fichero CSV y lo guarda en una tabla
        dataTable = readtable(handles.config.NOMBRE_FICHERO);
        
        decimalValues = dataTable.Valor;    % Extrae la columna de valores
        numRows = height(dataTable);        % Obtiene el número de filas
        
        % Pre-asigna memoria para las nuevas columnas para mayor eficiencia.
        binaryStrings = cell(numRows, 1);
        syncSignal = cell(numRows, 1);
        powerWatts = zeros(numRows, 1);
        
        % Bucle para procesar cada fila.
        for(i = 1:numRows)

            % Convierte el valor decimal a una cadena binaria de 16 bits
            tempBinary = dec2bin(decimalValues(i), 16);
            binaryStrings{i} = tempBinary;
            
            % Extrae el segundo bit de mayor peso
            syncSignal{i} = tempBinary(2);
            
            % Extrae los 14 bits de menor peso
            fourteenBitBinary = tempBinary(3:16);

            % Convierte esos 14 bits a decimal y multiplica por la constante
            powerWatts(i) = bin2dec(fourteenBitBinary) * handles.config.CONSTANTE_VATIOS;
        end
        
        % Añade las columnas calculadas a la tabla
        dataTable.Valor_Binario = binaryStrings;
        dataTable.senal_sincronizacion = syncSignal;
        dataTable.consumo_vatios = powerWatts;
        
        % Elimina las columnas que ya no son necesarias
        logMessage(src, 'Optimizando fichero de salida.');
        dataTable.Valor = [];
        dataTable.Valor_Binario = [];
        
        % Sobrescribe el fichero CSV con la tabla final optimizada
        logMessage(src, 'Guardando datos en el fichero asociado.');
        writetable(dataTable, handles.config.NOMBRE_FICHERO);
        
        logMessage(src, 'Proceso de adquisición de datos finalizado.');
        
    catch ME
        logMessage(src, '>> ERROR DURANTE EL PROCESAMIENTO <<');
        logMessage(src, ME.message);
        handles.lblStatus.Text = 'Error en el procesamiento.';
    end

end

% -------------------------------------------------------------------------

% ========================================================================
% transitionToFinalState
% Actualiza la interfaz al estado final después del procesamiento de datos
% ========================================================================

function transitionToFinalState(src)

    handles = guidata(src);
    handles.lblStatus.Text = 'Proceso finalizado. Puede cerrar el programa.';
    handles.btnStop.Visible = 'off';
    handles.btnClose.Visible = 'on';
    guidata(src, handles);

end

% -------------------------------------------------------------------------

% ========================================================================
% stopAcquisition
% Cambia el flag asociado para indicar que el bucle debe detenerse
% ========================================================================

function stopAcquisition(src, event)

    handles = guidata(src);
    handles.state.stopRequest = true;
    guidata(src, handles);

end

% -------------------------------------------------------------------------

% ========================================================================
% closeApp
% función encargada del cierre de la aplicación de forma adecuada
% ========================================================================

function closeApp(src, event)
    
% Obtiene el handle de la figura principal
    fig_handle = ancestor(src, 'figure'); 

    if(isvalid(fig_handle))
        cleanup(fig_handle, 'full_cleanup');    % Llama a la limpieza total
        delete(fig_handle);                     % Borra la figura
    end

end

% -------------------------------------------------------------------------

% ========================================================================
% cleanup
% Cierra todos los recursos empleados, fichero y puerto serie, de forma
% segura
% ========================================================================

function cleanup(src, stage)

    handles = guidata(src);
    
    % Comprueba si la limpieza es parcial por fin de adquisición de datos o
    % total por cierre de la aplicación
    if(nargin < 2)
        stage = 'full_cleanup';
    end
    
    if(strcmp(stage, 'acquisition_finished'))

        % Muestra el resumen de la adquisición.
        if(isfield(handles, 'resumen_final') && isfield(handles.resumen_final, 'muestras_totales') && handles.resumen_final.muestras_totales > 0)

            velocidad_media = handles.resumen_final.muestras_totales / handles.resumen_final.tiempo_total;
            logMessage(src, ' ');
            logMessage(src, '-- Adquisición Finalizada. -----------------------------------------------------------------');
            logMessage(src, sprintf('Se guardaron %d muestras en "%s".', handles.resumen_final.muestras_totales, handles.config.NOMBRE_FICHERO));
            logMessage(src, sprintf('Velocidad media: %.2f Muestras/seg.', velocidad_media));

        end

        logMessage(src, 'Cerrando puerto serie.');

    else
        logMessage(src, 'Cerrando todos los recursos...');
    end
    
    % Cierre seguro del fichero
    if ~isempty(handles.state.fileID)
        openFileIDs = openedFiles;
        if ismember(handles.state.fileID, openFileIDs), fclose(handles.state.fileID); end
    end
    handles.state.fileID = [];
    
    % Cierre seguro del puerto serie
    if ~isempty(handles.state.device)
        handles.state.device = []; 
    end
    
    if(strcmp(stage, 'full_cleanup'))
        logMessage(src, 'Recursos cerrados correctamente.')
    end

    guidata(src, handles);
end

% -------------------------------------------------------------------------

% ========================================================================
% logMessage
% Se añade un mensaje al área de texto y se realiza scroll hacia abajo
% ========================================================================

function logMessage(src, message)

    handles = guidata(src);
    if isvalid(handles.fig) && isfield(handles, 'logTextArea')
        handles.logTextArea.Value = [handles.logTextArea.Value; {message}];
        scroll(handles.logTextArea, 'bottom');
        drawnow('limitrate');
    end
end

% -------------------------------------------------------------------------