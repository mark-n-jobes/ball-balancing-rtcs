#include <AccelStepper.h>
#include <AFMotor.h>
#define MAX_STEPS 25
#define MODE DOUBLE   /* can be {SINGLE,DOUBLE,INTERLEAVE,MICROSTEP}  */
AF_Stepper Right(20, 1);
AF_Stepper Front(20, 2);
int DeltaStepsRight = 0;
int DeltaStepsFront = 0;
//------------------------------------------------------------------------//
void setup() {
    Serial.begin(9600);
    Serial.println("BallControlStart\n");
    Front.setSpeed(400);
    Right.setSpeed(400);
}
//------------------------------------------------------------------------//
void loop() {
    if(Serial.available() >  0) {
        char inChar;
        // Read serial input for CMD:
        inChar = (char)Serial.read();
        if ((inChar == 'F')&&(DeltaStepsFront <  MAX_STEPS)) {
            Front.onestep(FORWARD, MODE);
            DeltaStepsFront++;
        } else if ((inChar == 'f')&&(DeltaStepsFront > -MAX_STEPS)) {
            Front.onestep(BACKWARD, MODE);
            DeltaStepsFront--;
        } else if ((inChar == 'R')&&(DeltaStepsRight <  MAX_STEPS)) {
            Right.onestep(FORWARD, MODE);
            DeltaStepsRight++;
        } else if ((inChar == 'r')&&(DeltaStepsRight > -MAX_STEPS)) {
            Right.onestep(BACKWARD, MODE);
            DeltaStepsRight--;
        } else if (inChar == 'c') {
            DeltaStepsRight = 0;
            DeltaStepsFront = 0;
        } else if (inChar == 'C') {
            Front.release();
            Right.release();
        }
    }
}
//------------------------------------------------------------------------//
