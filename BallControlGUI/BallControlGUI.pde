//------------------------------------------------------------------------//
// Global
float ScreenScale  = 1.5;
float ScreenWidth  = 640*ScreenScale;
float ScreenHeight = 480*ScreenScale;
boolean UpdateENB = false;
// Serial
boolean SerialEnabled = true;
String inString = "";
import processing.serial.*;
Serial myPort;
// WiiRemote
import lll.wrj4P5.*;
import lll.Loc.*;
// Balls
WiiPointList FeedbackBall;
Point BallDest = new Point(ScreenWidth/2.,ScreenHeight/2.);
//------------------------------------------------------------------------//
void setup() {
    size(floor(ScreenWidth),floor(ScreenHeight));
    // create a font with the third font available to the system:
    PFont myFont = createFont(PFont.list()[2], 20);
    textFont(myFont);
    // Serial
    if(SerialEnabled) {
        println("Available ports are:");
        println(Serial.list());
        myPort = new Serial(this, Serial.list()[0], 9600);
    }
    // WiiRemote
    FeedbackBall = new WiiPointList(this);
}
//------------------------------------------------------------------------//
void draw() {
    //-----------Draw Prepare------------//
    background(0);
    // Update FeedBack Points
    FeedbackBall.UpdatePoints();
    //-----------Begin Draw------------//
    strokeWeight(16);
    // WiiRemote
    FeedbackBall.DrawAll(255,128,0);
    // Destination
    BallDest.DrawX(0,255,0);
    // Global vars
    text("UpdateENB:" + (String)((UpdateENB)?"true":"false"),20,20);
    //---------- Movement ----------//
    if(UpdateENB&&(BallDest.RelativeDist(FeedbackBall.ValidAvg) > 10)) {
        if     (FeedbackBall.NextPointGuess.X > BallDest.X) {myPort.write("r"); println("Sent:r");}
        else if(FeedbackBall.NextPointGuess.X < BallDest.X) {myPort.write("R"); println("Sent:R");}
        if     (FeedbackBall.NextPointGuess.Y > BallDest.Y) {myPort.write("F"); println("Sent:F");}
        else if(FeedbackBall.NextPointGuess.Y < BallDest.Y) {myPort.write("f"); println("Sent:f");}
    }
}
//------------------------------------------------------------------------//
void mousePressed() {
    BallDest = new Point(mouseX,mouseY);
}
//------------------------------------------------------------------------//
void keyPressed() {
    if     ( key == 'o')                       FeedbackBall.Offset.AddOffset(ScreenWidth/2.-FeedbackBall.ValidAvg.X,ScreenHeight/2.-FeedbackBall.ValidAvg.Y);
    else if( key == 'O')                       FeedbackBall.Offset.AddOffset(mouseX-FeedbackBall.ValidAvg.X,mouseY-FeedbackBall.ValidAvg.Y);
    else if((key == CODED)&&(keyCode == UP))   FeedbackBall.Scale *= 1.1;
    else if((key == CODED)&&(keyCode == DOWN)) FeedbackBall.Scale /= 1.1;
    else if( key == 'd') FeedbackBall.DrawOthers = !FeedbackBall.DrawOthers;
    else if((key == 'F')||(key == 'f')||(key == 'R')||(key == 'r')||(key == 'c')||(key == 'C')) {myPort.write(key);println(key);}
    else if( key == 'u') UpdateENB = !UpdateENB;
    // Others
    if( key == 'c') for(int i=0;i<4;i++) FeedbackBall.Points[i] = new Point(0,0);
}
//------------------------------------------------------------------------//
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class WiiPointList {
    Point [] Points;
    Point CurrRef = new Point(0,0);
    Point Offset = new Point(0,0);
    Point ValidAvg = new Point(0,0);
    Point NextPointGuess = new Point(0,0);
    Point Delta = new Point(0,0);
    int DeltaScale = 42;
    boolean PointsDefined = false;
    int numPoints = 0;
    boolean RemoteConnected = false;
    Wrj4P5 Remote;
    int DisplayStatus = 1;
    float Scale = ScreenScale;
    boolean FlipY = true;
    boolean FlipX = false;
    boolean DrawOthers = true;
    //------------------------------------------------------------------//
    WiiPointList(PApplet parent) {
        int count = 4; // Tracks 4 points
        this.Remote = new Wrj4P5(parent).connect(Wrj4P5.IR);
        this.numPoints = count;
        this.Points = new Point[count];
        for(int i=0;i < count;i++) this.Points[i] = new Point(0,0,0);
    }
    WiiPointList(float x, float y) {
        this.Offset = new Point(x,y);
        this.numPoints = 0;
    }
    //------------------------------------------------------------------//
    void UpdatePoints() {
        Point ValidAvg_temp = new Point(0,0);
        float numValid = 0;
        if(!this.RemoteConnected) {
            if(!this.Remote.isConnecting()) {
                this.RemoteConnected = true;
                println("WiiRemote connected!");
            }
        } else {
            this.PointsDefined = true;
            for (int i=0;i < this.numPoints;i++) {
                Loc p=this.Remote.rimokon.irLights[i];
                if (p.x > -1) { // Valid point
                    float x = (this.FlipX?(1.-p.x):p.x)*640*this.Scale+this.Offset.X;
                    float y = (this.FlipY?(1.-p.y):p.y)*480*this.Scale+this.Offset.Y;
                    float z = p.z*120*this.Scale;
                    this.Points[i] = new Point(x,y,z);
                    ValidAvg_temp.AddOffset(x,y,z);
                    numValid++;
                } else {
                    this.Points[i] = new Point(0,0);
                }
            }
            if(numValid != 0) {
                ValidAvg_temp.Scale(1./numValid);
                Point Delta_temp = new Point(ValidAvg_temp);
                Delta_temp.SubtractOffset(this.ValidAvg);
                Delta_temp.Z = 0; // Don't want this growing
                if(Delta_temp.SqrtSumSq() > 2) Delta_temp.Scale(this.DeltaScale); // Scale as to react in time (like looking into the future if velocity is constant)
                else                           Delta_temp = new Point(0,0);
                // Avg deltas for lpf
                Delta.AddOffset(Delta_temp);
                Delta.Scale(0.5);
                // Update Valid average
                this.ValidAvg = new Point(ValidAvg_temp.X,ValidAvg_temp.Y,ValidAvg_temp.Z);
                // Derrive next point assuming the velocity is constant (refresh just has to be fast enough) and go a few steps ahead
                this.NextPointGuess = new Point(this.ValidAvg);
                this.NextPointGuess.AddOffset(Delta);
            } else {
                this.ValidAvg = new Point(-100,-100);
                this.NextPointGuess = new Point(this.ValidAvg);
            }
        }
    }
    //------------------------------------------------------------------//
    void DrawAll(int r, int g, int b) {
        int i;
        stroke(r,g,b);
        fill  (r,g,b);
        if(this.PointsDefined) {
            for (i=0;i < this.numPoints;i++) this.Points[i].DrawSq(r,g,b);
            if(this.DrawOthers) {
                this.ValidAvg.DrawOX(255-r,255-g,255-b);
                this.NextPointGuess.DrawOX(255,0,0);
            }
        }
    }
    //------------------------------------------------------------------//
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class Point {
    float X,Y,Z; // Z is used for points' intensity
    //------------------------------------------------------------------//
    Point(Point In) {
        this.X = In.X;
        this.Y = In.Y;
        this.Z = In.Z;
    }
    Point(float x, float y) {
        this.X = x;
        this.Y = y;
        this.Z = 0;
    }
    Point(float x, float y, float z) {
        this.X = x;
        this.Y = y;
        this.Z = z;
    }
    //------------------------------------------------------------------//
    void Scale(float scaler) {
        this.X *= scaler;
        this.Y *= scaler;
        this.Z *= scaler;
    }
    //------------------------------------------------------------------//
    void AddOffset(Point Offset) {
        this.X += Offset.X;
        this.Y += Offset.Y;
        this.Z += Offset.Z;
    }
    void AddOffset(float X_offset, float Y_offset) {
        this.X += X_offset;
        this.Y += Y_offset;
    }
    void AddOffset(float X_offset, float Y_offset, float Z_offset) {
        this.X += X_offset;
        this.Y += Y_offset;
        this.Z += Z_offset;
    }
    //------------------------------------------------------------------//
    void SubtractOffset(Point Offset) {
        this.X -= Offset.X;
        this.Y -= Offset.Y;
        this.Z -= Offset.Z;
    }
    void SubtractOffset(float X_offset, float Y_offset) {
        this.X -= X_offset;
        this.Y -= Y_offset;
    }
    void SubtractOffset(float X_offset, float Y_offset, float Z_offset) {
        this.X -= X_offset;
        this.Y -= Y_offset;
        this.Z -= Z_offset;
    }
    //------------------------------------------------------------------//
    float RelativeDist(Point Ref) {
        return sqrt(((this.X-Ref.X)*(this.X-Ref.X))+((this.Y-Ref.Y)*(this.Y-Ref.Y)));
    }
    //------------------------------------------------------------------//
    float SqrtSumSq() {
        return sqrt((this.X*this.X)+(this.Y*this.Y));
    }
    //------------------------------------------------------------------//
    void DrawX(int r, int g, int b) {
        stroke(r,g,b);
        line(this.X-this.Z/2,this.Y-this.Z/2,this.X+this.Z/2,this.Y+this.Z/2);
        line(this.X-this.Z/2,this.Y+this.Z/2,this.X+this.Z/2,this.Y-this.Z/2);
    }
    void DrawX(int r, int g, int b, float Height) {
        stroke(r,g,b);
        Height/=2; // Scale once in begining is more efficient, but I guess no scale is better :)
        line(this.X-Height,this.Y-Height,this.X+Height,this.Y+Height);
        line(this.X-Height,this.Y+Height,this.X+Height,this.Y-Height);
    }
    //------------------------------------------------------------------//
    void DrawO(int r, int g, int b) {
        stroke(r,g,b);
        fill  (r,g,b);
        ellipse(this.X,this.Y,this.Z,this.Z);
    }
    void DrawO(int r, int g, int b, float Radius) {
        stroke(r,g,b);
        fill  (r,g,b);
        ellipse(this.X,this.Y,Radius,Radius);
    }
    //------------------------------------------------------------------//
    void DrawOX(int r, int g, int b) {
        stroke(r,g,b);
        noFill();
        ellipse(this.X,this.Y,this.Z,this.Z);
        this.DrawX(r,g,b);
    }
    void DrawOX(int r, int g, int b, float Radius) {
        stroke(r,g,b);
        noFill();
        ellipse(this.X,this.Y,Radius,Radius);
        this.DrawX(r,g,b,Radius);
    }
    //------------------------------------------------------------------//
    void DrawSq(int r, int g, int b) {
        stroke(r,g,b);
        fill  (r,g,b);
        rect(this.X-this.Z/4,this.Y-this.Z/4,this.Z/2,this.Z/2);
    }
    void DrawSq(int r, int g, int b, float Height) {
        stroke(r,g,b);
        fill  (r,g,b);
        Height/=2; // Scale once in begining is more efficient, but I guess no scale is better :)
        rect(this.X-Height/2,this.Y-Height/2,Height,Height);
    }
    //------------------------------------------------------------------//
    void PrintID(int ID) {
        text("ID:" + ID, this.X-20,this.Y-20);
    }
    //------------------------------------------------------------------//
    void Print(String InStr) {
        text(InStr, this.X-InStr.length()*6,this.Y-20);
    }
    //------------------------------------------------------------------//
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

