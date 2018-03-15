#include <Adafruit_VS1053.h>
#include <SPI.h>
#include <SD.h>
#include <EEPROM.h>                                              //Include the EEPROM Library in this sketch.

int shock_led = A4;
int shock_pin = 7;

int vns_pin = A2;
int vns_led= A3;


//a is MSB, d is LSB
int music_led = A5;
int tone_select_a = 8;
int tone_select_b = 9;
int tone_select_c = 10;
int tone_select_d = 11;
int music_trigger = 12;
int read_music = 13;

byte mode[]={0,0,0,0};
int val;
unsigned int byteA;

int booth_num = 0;
int input=0;

long stream_input=0;

boolean stream_enable=0;
unsigned long stream_period = 10;                                      //Set the time between stream writes, in milliseconds.
unsigned long next_stream, read_time, stream_start;                       //Create unsigned long variables for timing a periodic data stream.

boolean input_enabled[] = {1, 0, 0, 0, 0, 0};

void setup()
{

  pinMode(shock_led, OUTPUT);
  pinMode(shock_pin, OUTPUT);
  pinMode(vns_led, OUTPUT);
  pinMode(vns_pin, OUTPUT);
  pinMode(music_led, OUTPUT);
  pinMode(music_trigger, OUTPUT);
  pinMode(tone_select_a, OUTPUT);
  pinMode(tone_select_b, OUTPUT);
  pinMode(tone_select_c, OUTPUT);
  pinMode(tone_select_d, OUTPUT);
  pinMode(read_music,INPUT);
  
  //Initialize the serial connection.
  Serial.begin(115200);                                          //Set the baud rate for serial data transmission.
  

}

void loop() 
{
  
  if (Serial.available() > 0) //If there's a new incoming command on the serial line...
  {                                  
      val=Serial.read();

      switch (mode[0])
      {
        
      case 0:
      //If serial read is an "A"
      if(val == 'A')
      {
          Serial.print(1);
          Serial.print("\t");
          Serial.print(0);
          Serial.print("\n");
        
      }
      
      //If serial read is a "B": set booth num
      else if( val == 'B') 
      {
        Serial.println(booth_num);
      }
  
      //If serial read is a "b": display booth num
      else if (val == 'b') 
      {
        booth_num = EEPROM.read(0);
        Serial.println(booth_num);
      }
  
      //If serial read is a "C": enable/disable shock
      else if (val == 'C')
      {
         mode[0]=2;
      }

      //If serial read is a "D": enable vns pulse of 5ms
      else if (val == 'D')
      { 
         digitalWrite(vns_led,1);
         digitalWrite(vns_pin,1);
         delay(5);
         digitalWrite(vns_pin,0);
      }

      //If serial read is an "E": select tone outputs
      else if (val == 'E')
      {
        mode[0]=3;
        mode[1]=4;
      }


      //If serial read is an "F": enable/disable tone
      else if (val == 'F')
      {
        mode[0]=5;
      }


      //If serial read is a "G": read input from music board
      else if (val == 'G')
      {
        input=digitalRead(read_music);
        Serial.println(input);
      }

      //If serial read is a "g": enable stream
      else if (val == 103) 
      {
        mode[0]=17;
      }

      //If serial read is an H: turn off music indicator
      else if (val == 'H')
      {
        digitalWrite(music_led,0);
      }

      //If serial read is a J: turrn off VNS indicator
      else if (val == 'J')
      {
        digitalWrite(vns_led,0);
      }
      break; 

      //Enable or disable shock
      case 2:
        val=val-48;
        if (val == 1) 
        {
          digitalWrite(shock_pin,1);
          digitalWrite(shock_led,1);
        }
        else 
        {
          digitalWrite(shock_pin,0);                                 
          digitalWrite(shock_led,0);
        }
        mode[0]=0;
        break;

     case 3:                                                    //When mode equals 7, the read value is the first byte of a 16-bit integer.
        byteA = val;                                             //Save the read value to the byteA variable.
        mode[0] = mode[1];                                       //Set the next mode to the second specified mode.
        mode[1] = mode[2];                                       //Set the second mode to the third specified mode.
        mode[2] = mode[3];                                       //Set the third mode to the fourth specified mode.
        break;

     //Enable tone selector pins
     case 4:
        byteA=val+(byteA<<8);         
        digitalWrite(tone_select_a, HIGH && (byteA & B00001000));
        digitalWrite(tone_select_b, HIGH && (byteA & B00000100));
        digitalWrite(tone_select_c, HIGH && (byteA & B00000010));
        digitalWrite(tone_select_d, HIGH && (byteA & B00000001));       
        mode[0]=0;
        break;

    //Enable music
    case 5:

        val=val-48;
        if(val == 1)
        {
          digitalWrite(music_trigger,1);
          digitalWrite(music_led,1);
        }
        
        else
        {
          digitalWrite(music_trigger,0);
        }
        mode[0]=0;
        break;

    //Stream Enable
    case 17:                                                   
       stream_enable = val - 48;
       stream_start = millis();
       next_stream = stream_start + stream_period;
       mode[0] = 0;
       break;

     
         
     }
  }
     
  if ((stream_enable == 1) && (millis() > next_stream))         //If periodic streaming is enabled and it's time for the next stream write...
  {                                                       
    stream_input= analogRead(read_music);
    read_time = millis() - stream_start ;                       //Grab the current microsecond clock time minus the stream start time.
    Serial.print(read_time);                                    //Print the current microsecond clock reading to the serial line.
    Serial.print("\t");                                         //Print a tab.
    Serial.print(stream_input);                                        //Print the value of the analog input to the serial line.                                                         //Print the current value of the stream IR input to the serial line.
    Serial.print("\n");                                         //Print a new line indicator.
    next_stream = next_stream + stream_period;                  //Set the timing for the next stream period.
  }
  
    
}
