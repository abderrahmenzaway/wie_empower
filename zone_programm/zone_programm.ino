#include <SoftwareSerial.h>
#include <WiFiEspAT.h>
SoftwareSerial espSerial(0, 1); // RX, TX
const char* WIFI_SSID = "YourPiSSID";
const char* WIFI_PASS = "YourPiPassword";
const char* SERVER_IP = "192.168.4.1";
const uint16_t SERVER_PORT = 8000;
WiFiClient client;
unsigned long lastPingMs = 0;
#define hum1 A5 
#define hum2 A4 
#define hum3 A3 
#define pump 2
unsigned long myTime;
void ensureWiFiConnected() {
  if (WiFi.status() == WL_CONNECTED) return;

  Serial.print(F("Connecting to WiFi: "));
  Serial.println(WIFI_SSID);

  // Try multiple times
  for (int i = 0; i < 10 && WiFi.status() != WL_CONNECTED; i++) {
    int r = WiFi.begin(WIFI_SSID, WIFI_PASS);
    if (r == WL_CONNECTED) break;
    Serial.print(F("Retry WiFi... status="));
    Serial.println(WiFi.status());
    delay(1000);
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print(F("WiFi connected, IP: "));
    Serial.println(WiFi.localIP());
  } else {
    Serial.println(F("Failed to connect to WiFi."));
  }
}
void setup() {
  pinMode(hum1,INPUT);
  pinMode(hum2,INPUT);
  pinMode(hum3,INPUT);
  pinMode(pump,OUTPUT);
  /////////////wifi config /////////////
  espSerial.begin(9600);
  delay(200);
  WiFi.init(espSerial);
  ensureWiFiConnected();
  myTime = micros();
}
int t=0;
bool h=false ;
int moyen ;
int seuil=200;
long pump_duration ;
String response = "";
void loop() {
  if (client.available()){
          response = client.readStringUntil('\n');
          if (response=="turn on pump") digitalWrite(pump,1);
          else{
          if (response=="turn off pump")  digitalWrite(pump,0);}
  }
  else{
  if(myTime-micros()==360000){
    t=0;
    h=false ;
    myTime = micros();
    // Replace your block:
    if (client.connected() || client.connect(SERVER_IP, SERVER_PORT)) {
      moyen = (analogRead(hum1) + analogRead(hum2) + analogRead(hum3)) / 3;
    //client.print("GET /submit?v=");
      client.print(moyen);
    }
    while(myTime-micros()<5000){
       // Use a String to read the full number
      if (client.connected()) {
  // Read the response from the server until a newline is found
        if (client.available()){
          h=true;
          response = client.readStringUntil('\n');
          pump_duration = response.toInt(); // Convert the string to an integer
        }
        
      }
    }
    }
    myTime = micros();
  if(h){
  if(t==0){
  digitalWrite(pump,1);
  delay(pump_duration);
  digitalWrite(pump,0);
  t=1;
  }
  }
  else{
    moyen = (analogRead(hum1) + analogRead(hum2) + analogRead(hum3)) / 3;
    if(moyen<seuil) {
    digitalWrite(pump,1);
    while(moyen<seuil);
    digitalWrite(pump,0); 
    }
  }
  }
}

