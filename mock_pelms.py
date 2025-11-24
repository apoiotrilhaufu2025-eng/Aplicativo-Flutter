import paho.mqtt.client as mqtt
import pymysql  
import json
import time
import traceback

# --- Configurações do MQTT ---
MQTT_BROKER = "192.168.15.79" 
MQTT_PORTA = 1883
MQTT_TOPICO = "trilha/eventos/passagem"

# --- Configurações do MySQL ---
MYSQL_HOST = "127.0.0.1"
MYSQL_USUARIO = 
MYSQL_SENHA =  
MYSQL_BANCO = "aplicativotrilhamapl"
MYSQL_PORTA = 3306  

def conectar_mysql():
    """Tenta conectar ao banco de dados MySQL."""
    try:
        conexao = pymysql.connect(
            host=MYSQL_HOST,
            user=MYSQL_USUARIO,
            password=MYSQL_SENHA,
            database=MYSQL_BANCO,
            port=MYSQL_PORTA
        )
        print("[Mock-PELMS] Conectado ao banco de dados MySQL com sucesso! (Usando PyMySQL)")
        return conexao
    except pymysql.Error as err:
        print(f"[Mock-PELMS] Erro ao conectar ao MySQL: {err}")
        return None

def salvar_evento(payload_json):
    """Salva o evento de passagem no banco de dados."""
    conexao = None
    cursor = None
    
    try:
        conexao = conectar_mysql()
        if conexao is None:
            print("[Mock-PELMS] Não foi possível salvar o evento. Conexão com o BD falhou (ver log anterior).")
            return

        id_usuario = payload_json.get('id_usuario')
        id_tag = payload_json.get('id_tag')
        timestamp_leitura = payload_json.get('timestamp_leitura')
        direcao = payload_json.get('direcao', 'ida')


        cursor = conexao.cursor()
        sql = """
        INSERT INTO eventos_passagem 
        (id_usuario, id_tag, timestamp_leitura, direcao) 
        VALUES (%s, %s, %s, %s)
        """
        valores = (id_usuario, id_tag, timestamp_leitura, direcao)
        
        cursor.execute(sql, valores)
        conexao.commit()
        
        print(f"[Mock-PELMS] Evento salvo! Usuário: {id_usuario}, Tag: {id_tag}")


    except pymysql.Error as err:
        print(f"[Mock-PELMS] Erro de SQL ao salvar no BD: {err}")
        if conexao:
            conexao.rollback()
    except Exception as e:
        print(f"[Mock-PELMS] Erro inesperado DENTRO de salvar_evento: {e}")
        traceback.print_exc()
    finally:
        if cursor:
            cursor.close()
        if conexao:
            conexao.close()

# --- Funções Callback do MQTT ---

def on_connect(client, userdata, flags, rc):
    """Callback chamado quando o cliente se conecta ao broker."""
    if rc == 0:
        print("[Mock-PELMS] Conectado ao Broker MQTT!")
        client.subscribe(MQTT_TOPICO)
        print(f"[Mock-PELMS] Inscrito no tópico: {MQTT_TOPICO}")
    else:
        print(f"[Mock-PELMS] Falha na conexão MQTT, código: {rc}")

def on_message(client, userdata, msg):
    """Callback chamado quando uma mensagem é recebida."""
    print(f"\n[Mock-PELMS] Mensagem recebida! Tópico: {msg.topic}")
    
    try:
        payload_str = msg.payload.decode('utf-8')
        payload_json = json.loads(payload_str)
        
        print(f"[Mock-PELMS] Payload: {payload_json}")
        print("[Mock-PELMS] Validando transição (simulado)...")
        salvar_evento(payload_json)
        
    except json.JSONDecodeError:
        print("[Mock-PELMS] Erro: Mensagem recebida não é um JSON válido.")
    except Exception as e:
        print(f"[Mock-LMS] Erro inesperado no 'on_message': {e}")
        traceback.print_exc()

def on_disconnect(client, userdata, rc):
    """Callback chamado quando o cliente se desconecta."""
    print(f"[Mock-PELMS] Desconectado do Broker MQTT! Código: {rc}")
    if rc != 0:
        print("[Mock-PELMS] Tentando reconectar em 5 segundos...")
        time.sleep(5)
        client.reconnect()

# --- Configuração e Loop Principal ---

print("[Mock-PELMS] Iniciando serviço...")
client = mqtt.Client(client_id="mock-pelms-listener")

client.on_connect = on_connect
client.on_message = on_message
client.on_disconnect = on_disconnect

try:
    client.connect(MQTT_BROKER, MQTT_PORTA, 60)
except Exception as e:
    print(f"[Mock-PELMS] Não foi possível conectar ao Mosquitto em {MQTT_BROKER}:{MQTT_PORTA}.")
    print("Verifique se o Mosquitto está rodando.")
    exit(1)

print("[Mock-PELMS] Ouvindo por mensagens... (Pressione CTRL+C para parar)")
client.loop_forever()