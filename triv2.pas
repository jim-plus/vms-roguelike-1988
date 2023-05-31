[inherit('sys$library:starlet')]

program trivial(input,output,savefile);

{Completion date: December 30, 1988
Author:
    Jim Wen-tzen Lai
Contributing authors:
    David K. MacKinnon, DKMK Enterprises
    David Newport

This program may be freely modified and/or distributed provided:
 1. This notice is not removed.
 2. The program is not to be traded, sold, or otherwise used for personal gain.
 3. Credit is not taken for creation of the source.
 4. Any further modifications are documented in these credits.
I am not responsible nor liable for losses (real or imagined) incurred due to
the use, misuse, abuse, and/or overuse of this program. -- JWL}

const
    version='4.051';
    n=7; {size of maze}
    armors=9; {number of types of armor}
    monsters=20; {number of types of monsters}
    potions=12; {number of types of potions}
    races=8; {number of races}
    weapons=9; {number of types weapons}
    spells=13; {number of spells}
    targetlev=7; {Shred of Truth is found on target level}
    trade=500; {cost of trading factor}
    toplevel=20; {maximum level of experience}
    clear='x'; {see map symbols command in procedure dotask}
    ladder='=';
    shred='*';
    vendor='$';
    ration='+';
    esc=chr(27);
    vowels=['a','e','i','o','u'];
    null=chr(0);

type
    grid=array[1..N,1..N]of integer;
    test=array[1..N,1..N]of boolean;
    content=array[1..N,1..N]of char;
    unsigned_word=[word] 0..65535;
    filespec=varying[80]of char;
    nametype=varying[20]of char;
        {Note that for varying[n], n may have to be
         increased if an added name is too long.}
    armorstr=array[1..armors]of varying[22]of char;
    colorstr=array[1..potions]of varying[7]of char;
    callstr=array[1..spells]of varying[11]of char;
    potionstr=array[1..potions]of varying[19]of char;
    racestr=array[1..races]of varying[14]of char;
    racestat=array[1..races]of integer;
    spellstr=array[1..spells]of varying[15]of char;
    titlestr=array[0..toplevel]of varying[30]of char;
    weaponstr=array[1..weapons]of varying[16]of char;
    armstat=array[1..armors]of integer;
    monstat=array[1..monsters]of integer;
    monstr=array[1..monsters]of varying[29]of char;
    potident=array[1..potions]of boolean;
    potstat=array[1..potions]of integer;
    spelltest=array[1..spells]of boolean;
    spellstat=array[1..spells]of integer;
    weapstat=array[1..weapons]of integer;
    quirks=(gold,potion,scroll);
    quirk=set of quirks;
    mtrait=array[1..monsters]of quirk;

var
    savefile:text;
    savespec:filespec;
    armorname:armorstr;
    color:colorstr;
    potionname:potionstr;
    creature:monstr;
    racename:racestr;
    rhp,rsp,maxspells:racestat;
    spellcall:callstr;
    spellknow:spelltest;
    spellname:spellstr;
    title:titlestr;
    weaponname:weaponstr;
    map,monster,mhp:grid;
        {There is a passage between two adjacent rooms if and only if
         the numbers in map[] are different.}
    visited:test;
        {Has a room been visited before?}
    rooms:content;
        {Character array indicating contents of rooms, except for
         monsters.  Can be used in tests.}
    gparm,armprot:armstat;
    mhps,m2hit,m2bhit,mdmg,mxp:monstat;
    mtraits:mtrait;
    potfind:potident;
    potclr,potgot,potamt:potstat;
    scrgot,scramt,spellcost,spellgot,spelltran:spellstat;
    gpweap,weapdmg:weapstat;
    name:nametype;
    food,hunger,gp,hp,hpmax,sp,spmax,race,xp,kills,level,levels,x,y,
        gotarmor,gotweapon,potkinds,scrkinds,hpweb,spellsknown,xplev,
        nextlev:integer;
    dead,moved,quit,samelev,victorious,gotshred:boolean;
    keyboard:unsigned;

{terminal keyboard interface for cbreak() mode}
procedure smg$read_keystroke(
    keyboard_id:unsigned;var terminator_code:integer;
    prompt:packed array[a..b:integer]of char;timeout:integer); extern;
procedure smg$create_virtual_keyboard(
    var new_keyboard_id:unsigned); extern;

function readletter:integer; {wait only 10 times to be added?}
var i:integer;
begin
    i:=509;
    while i<>509 do begin
        smg$read_keystroke(keyboard,i,null,15);
        {global reference to variable keyboard}
        if i=509 then writeln('   We don''t have all day.');
    end;
    readletter:=i
end;

{command line interface}
function cli$get_value(
    entity_desc:packed array[a..b:integer]of char;
    var retdesc:packed array[c..d:integer]of char;
    var retlength:unsigned_word):unsigned; extern;
function cli$present(
    entity_desc:packed array[a..b:integer]of char):boolean; extern;

function randb(x:integer):integer; external;

function rand2(x,y:integer):integer;
var i,j:integer;
begin
    j:=0; for i:=1 to x do j:=j+randb(y); rand2:=j;
end;

procedure locate(y,x:integer);
    begin write(esc,'[',y:1,';',x:1,'H') end;

procedure pauseline;
var i:integer;
begin
    write(esc,'[4m [Press return to continue]',esc,'[0m');
    locate(23,1); writeln;
    repeat i:=readletter until i=13;
    writeln(esc,'[K',esc,'[A');
end;

procedure cls;
    begin write(esc,'[2J') end;

procedure window(top,bot:integer);
    begin write(esc,'[',top:1,';',bot:1,'r') end;

procedure showhp;
    begin locate(5,n*3+15); writeln(hp:1,'(',hpmax:1,') ') end;

procedure showsp;
    begin locate(11,n*3+17); writeln(sp:1,'(',spmax:1,') ') end;

procedure putsave;
var i,j:integer;
begin
    open(savefile,savespec,new); rewrite(savefile);
    writeln(savefile,gp:1,' ',hp:1,' ',hpmax:1,' ',sp:1,' ',spmax:1);
    writeln(savefile,race:1,' ',xp:1,' ',kills:1,' ',level:1);
    writeln(savefile,x:1,' ',y:1);
    writeln(savefile,gotarmor:1,' ',gotweapon:1,' ',potkinds:1);
    writeln(savefile,scrkinds:1,' ',spellsknown:1,' ',xplev:1);
    writeln(savefile,nextlev:1,gotshred:1);
    for i:=1 to N do for j:=1 to N do begin
        writeln(savefile,map[i,j]:1,' ',monster[i,j]:1);
        writeln(savefile,mhp[i,j]:1,visited[i,j]:1);
        writeln(savefile,rooms[i,j]:1);
    end;
    for i:=1 to potions do
        writeln(savefile,potclr[i]:1,' ',potfind[i]:1);
    for i:=1 to spells do
        writeln(savefile,spelltran[i]:1,' ',spellknow[i]:1);
    for i:=1 to potkinds do
        writeln(savefile,potamt[i]:1,' ',potgot[i]:1);
    for i:=1 to spellsknown do
        writeln(savefile,spellgot[i]:1);
    for i:=1 to scrkinds do
        writeln(savefile,scrgot[i]:1,' ',scramt[i]:1);
    writeln(savefile,name);
    writeln(savefile,hpweb:1,' ',levels:1,' ',food:1,' ',hunger:1);
    close(savefile);
end;

procedure getsave;
var i,j:integer;
begin
    samelev:=true;
    open(savefile,savespec,old); reset(savefile);
    readln(savefile,gp,hp,hpmax,sp,spmax);
    readln(savefile,race,xp,kills,level);
    readln(savefile,x,y);
    readln(savefile,gotarmor,gotweapon,potkinds);
    readln(savefile,scrkinds,spellsknown,xplev);
    readln(savefile,nextlev,gotshred);
    for i:=1 to N do for j:=1 to N do begin
        readln(savefile,map[i,j],monster[i,j]);
        readln(savefile,mhp[i,j],visited[i,j]);
        readln(savefile,rooms[i,j]);
    end;
    for i:=1 to potions do
        readln(savefile,potclr[i],potfind[i]);
    for i:=1 to spells do
        readln(savefile,spelltran[i],spellknow[i]);
    for i:=1 to potkinds do
        readln(savefile,potamt[i],potgot[i]);
    for i:=1 to spellsknown do
        readln(savefile,spellgot[i]);
    for i:=1 to scrkinds do
        readln(savefile,scrgot[i],scramt[i]);
    readln(savefile,name);
    readln(savefile,hpweb,levels,food,hunger);
    close(savefile);
end;

procedure leveltitle(xplev:integer);
begin
    if(xplev<toplevel)then write(title[xplev]) else write(title[toplevel]);
    writeln(esc,'[K');
end;

function getmonster(level:integer):integer;
{This function tells which monsters will appear on a given level.}
begin
    if(not gotshred)then getmonster:=randb(3)+level*2-2
    else getmonster:=randb(monsters-3)+2;
end;

function getpotion:integer;{This function hands out the potions.}
var x:integer;
begin
    x:=randb(130);
    if x<=40 then getpotion:=1
    else if x<=60 then getpotion:=2
    else if x<=75 then getpotion:=3
    else if x<=95 then getpotion:=4
    else if x<=100 then getpotion:=5
    else if x<=105 then getpotion:=6
    else if x<=110 then getpotion:=7
    else if x<=115 then getpotion:=8
    else if x<=120 then getpotion:=9
    else if x<=125 then getpotion:=10
    else if x<=130 then getpotion:=11;
end;

function getscroll:integer;{This function hands out the spells.}
var x:integer;
begin
    x:=randb(140);
    if x<=20 then getscroll:=1
    else if x<=40 then getscroll:=2
    else if x<=60 then getscroll:=3
    else if x<=80 then getscroll:=4
    else if x<=85 then getscroll:=5
    else if x<=100 then getscroll:=6
    else if x<=110 then getscroll:=7
    else if x<=115 then getscroll:=8
    else if x<=120 then getscroll:=9
    else if x<=125 then getscroll:=10
    else if x<=130 then getscroll:=11
    else if x<=135 then getscroll:=12
    else if x<=140 then getscroll:=13;
end;

procedure drawroom(dx,dy:integer);
begin
    if visited[x,y] then begin locate(y*2-1,x*3-2); write(rooms[x,y]); end;
    x:=x+dx; y:=y+dy;
    locate(y*2-1,x*3-2);
    write(esc,'[4m',rooms[x,y],esc,'[0m');
    if(not visited[x,y])then begin
        visited[x,y]:=true;
        if(x<N)then if(not visited[x+1,y])and(map[x,y]<>map[x+1,y])then
            begin locate(y*2-1,x*3-1); write('..'); end;
        if(x>1)then if(not visited[x-1,y])and(map[x,y]<>map[x-1,y])then
            begin locate(y*2-1,x*3-4); write('..'); end;
        if(y<N)then if(not visited[x,y+1])and(map[x,y]<>map[x,y+1])then
            begin locate(y*2,x*3-2); write(':'); end;
        if(y>1)then if(not visited[x,y-1])and(map[x,y]<>map[x,y-1])then
            begin locate(y*2-2,x*3-2); write(':'); end;
    end;
    locate(23,1); writeln;
    if(abs(dx)+abs(dy)>0)or(not samelev)then
    if(rooms[x,y]=ladder)then writeln('There is a ladder here.')
    else if(rooms[x,y]=vendor)then writeln('There is a vendor here.')
    else if(rooms[x,y]=ration)then writeln('There is food here.')
    else if(rooms[x,y]=shred)and(not gotshred)
        then writeln('The Shred of Truth is here!');
end;

procedure drawscreen;
begin
    Cls;
    Window(N*2+1,24);
    locate(1,N*3+3); write('Dungeon level: ',level:1);
    locate(3,N*3+3); write('Gold pieces: ',gp:1);
    locate(4,N*3+3); write('Food rations: ',food:1);
    locate(5,N*3+3); write('Hit points:'); showhp;
    locate(7,N*3+3); write('Monsters defeated: ',kills:1);
    locate(9,N*3+3); write('Experience points: ',xp:1);
    locate(11,N*3+3); write('Spell points:'); showsp;
    locate(13,N*3+3); write('Spells known: ',spellsknown:1);
    locate(1,N*3+33); write('Rank:');
    locate(2,N*3+33); leveltitle(xplev);
    locate(4,N*3+33); writeln('Race:');
    locate(5,N*3+33); write(racename[race]);
    locate(7,N*3+33); write('Armor:');
    locate(8,N*3+33); write(armorname[gotarmor]);
    locate(10,N*3+33); writeln('Weapon:');
    locate(11,N*3+33); write(weaponname[gotweapon]);
    locate(13,N*3+33); writeln('Name: ',name);
    locate(23,1); writeln
end;

procedure newmap;
var str:packed array[1..N*3-2]of char;
    i,j:integer;
begin
    locate(1,1);
    for i:=1 to n do begin
        str:=' ';
        for j:=1 to n do begin
            if visited[j,i] then str[j*3-2]:=rooms[j,i];
            if(j<n)then if(visited[j,i] or visited[j+1,i])and
                (map[j,i]<>map[j+1,i])
                then begin str[j*3-1]:='.'; str[j*3]:='.'; end;
        end;
        writeln(str);
        if(i<n)then begin
            str:=' ';
            for j:=1 to n do if(visited[j,i] or visited[j,i+1])and
                (map[j,i]<>map[j,i+1])then str[j*3-2]:=':';
            writeln(str);
        end;
    end;
    drawroom(0,0);
    locate(23,1); writeln
end;

procedure drawdisplay;
begin
    drawscreen;
    newmap;
end;

function buyarmor(factor:integer):integer;
var i,j:integer;
begin
    writeln('You have ',gp:1,' gp.');
    writeln('"What armor will you buy?  I can sell you the following:"');
    for i:=1 to armors do if(gp>=gparm[i]*factor)then
        writeln(chr(96+i),') ',armorname[i],' (',gparm[i]*factor:1,
        ' gp)');
    j:=readletter-96;
    if(j<0)or(j>armors)then j:=0;
    if(j>0)then if(gp<gparm[j]*factor)then j:=0;
    if(j=0)then writeln('"I can''t sell you such an armor!"')
    else begin
        gp:=gp-gparm[j]*factor;
        if(j>1)then writeln('"Sold!"')else
        writeln('"Try to make a deal for somebody..."')
    end;
    buyarmor:=j;
end;

function buyweapon(factor:integer):integer;
var i,j:integer;
begin
    writeln('You have ',gp:1,' gp.');
    writeln('"What weapon will you buy?  I can sell you the following:"');
    for i:=1 to weapons do if(gp>=gpweap[i]*factor)then
        writeln(chr(96+i),') ',weaponname[i],' (',gpweap[i]*factor:1,
        ' gp)');
    j:=readletter-96;
    if(j<0)or(j>weapons)then j:=0;
    if(j>0)then if(gp<gpweap[j]*factor)then j:=0;
    if(j=0)then writeln('"You cannot buy such a weapon!"')
    else begin
        gp:=gp-gpweap[j]*factor;
        if(j>1)then writeln('"Sold!"')else
        writeln('"Fine, then.  Be that way," the vendor grumbles.')
    end;
    buyweapon:=j
end;

procedure runvend;
var found:boolean;
    i,j,price:integer;
begin
    cls;
    window(1,24);
    locate(1,1);
    writeln('He leads you under a sign which reads, ',
        '"BENNY''S BARGAIN BASEMENT."');
    writeln('He says to you, "Would you like to see what I have?"');
    writeln('"I carry a full line of weapons (none guaranteed)."');
    if gotweapon>1 then
        writeln('You will have to trade in your weapon, though.');
    i:=buyweapon(5+levels*10);
    if i>1 then gotweapon:=i;
    writeln('"Moving right along, let''s take a look my selection of ',
        'fine armor.');
    writeln('You''re getting the best deal anywhere on this level."');
    if gotarmor>1 then
        writeln('You will have to trade in your armor, though.');
    i:=buyarmor(5+levels*10);
    if i>1 then gotarmor:=i;
    price:=levels*150;
    if(gp>=price)then begin
        writeln('"Maybe it''s potions you want.  Saves you time ',
            'trying find them.  We have a');
        writeln('complete selection, all guaranteed to work.  So, do ',
            'you want to pick one out of');
        writeln('our sack of holding?  The price is ',price:1,' gp."');
        j:=readletter-96;
        if j=25 then begin
            writeln('"A fine choice, sir.  It looks like the best ',
                'one there."');
            gp:=gp-price;
            i:=getpotion;
            found:=false;
            for j:=1 to potkinds do
                if(potgot[j]=i)then begin
                    found:=true;
                    potamt[j]:=potamt[j]+1
                end;
            if(not found)then begin
                potkinds:=potkinds+1;
                potgot[potkinds]:=i;
                potamt[potkinds]:=1
            end
        end else writeln('"You really are hard to please."');
    end;
    price:=levels*200;
    if(gp>=price)then begin
        writeln('"I know what you really want."  A smile crosses ',
            'his face.  "A scroll!');
        writeln('We have a complete line of unread scrolls.  Of ',
            'course we don''t know');
        writeln('what''s on them, but take a chance."  He brings out ',
            'a bag of holding.');
        writeln('"For you, the bargain price of ',price:1,' gp.  ',
            'So, want to pick one?"');
        j:=readletter-96;
        if j=25 then begin
            writeln('"Boy, I wish I had your luck!"');
            gp:=gp-price;
            i:=getscroll;
            found:=false;
            for j:=1 to scrkinds do
                if(scrgot[j]=i)then begin
                    found:=true;
                    scramt[j]:=scramt[j]+1
                end;
            if(not found)then begin
                scrkinds:=scrkinds+1;
                scrgot[scrkinds]:=i;
                scramt[scrkinds]:=1
            end
        end
        else writeln('"Fine, don''t buy anything, see if I care!"');
    end;
    writeln('[Press return to leave the vendor''s store]');
    repeat i:=readletter until i=13;
    drawdisplay;
    writeln('You have just left the vendor.');
end;

procedure KillPath(paths:integer; var map:grid);
var i,x,y:integer;
begin
    for i:=1 to paths do if odd(i) then begin
        repeat x:=randb(N); y:=randb(N-1);
        until (map[x,y]+map[x,y+1]=-1);
        map[x,y]:=i; map[x,y+1]:=i;
    end else begin
        repeat x:=randb(N-1); y:=randb(N);
        until (map[x,y]+map[x+1,y]=-1);
        map[x,y]:=i; map[x+1,y]:=i;
    end;
end;

procedure initlevel;
var i,j,vx,vy:integer;
begin
    levels:=levels+1;
    vx:=randb(N); vy:=randb(N);
    for i:=1 to N do for j:=1 to N do begin
        map[i,j]:=((i+j)mod 2)-1;
        if(i=vx)and(j=vy)then rooms[i,j]:=vendor
        else begin
            if(randb(100)<=25)then begin
                monster[i,j]:=getmonster(level);
                mhp[i,j]:=mhps[monster[i,j]];
            end;
            rooms[i,j]:=clear;
        end;
        visited[i,j]:=false;
    end;
    repeat i:=randb(N); j:=randb(N) until rooms[i,j]=clear;
    rooms[i,j]:=ladder;
    repeat i:=randb(N); j:=randb(N) until rooms[i,j]=clear;
    rooms[i,j]:=ration;
    if(level=targetlev)then begin
        repeat i:=randb(N); j:=randb(N) until rooms[i,j]=clear;
        rooms[i,j]:=shred;
        monster[i,j]:=monsters;
        mhp[i,j]:=mhps[monster[i,j]]
    end;
    x:=randb(N); y:=randb(N);
    KillPath(2*(N-1),map);
    for i:=1 to(N*2-1)do
        begin locate(i,N*3-2); writeln(esc,'[1K'); end;
    drawroom(0,0);
end;

procedure Warn;
begin
    case randb(6) of
        1:write('You find yourself facing a ');
        2:write('You are confronted by a ');
        3:write('You are face-to-face with a ');
        4:write('Before you stands a ');
        5:write('You are in the presence of a ');
        6:write('In front of you is a ');
    end;
    writeln(creature[monster[x,y]],'.');
end;

procedure Hit;
begin
    case randb(8) of
        1:write('struck');
        2:write('hit');
        3:write('injured');
        4:write('swung and hit');
        5:write('mangled');
        6:write('nicked');
        7:write('hurt');
        8:write('scratched');
    end;
end;

procedure missed;
begin
    case randb(8) of
        1:write('swung and missed');
        2:write('missed');
        3:write('barely missed');
        4:write('didn''t hit');
        5:write('swung wildly and missed');
        6:write('hit the wall instead of');
        7:write('struck the floor, but not');
        8:write('missed, merely annoying');
    end;
end;

procedure advancelevel;
var i:integer;
begin
    if xp>=nextlev then begin
        nextlev:=nextlev+1000;
        xplev:=xplev+1;
        if(xplev>=(toplevel div 2))then nextlev:=nextlev+1000;
        if(xplev>=(toplevel*3)div 4)then nextlev:=nextlev+1000;
        if(xplev>=toplevel)then nextlev:=maxint;
        locate(2,N*3+33);
        leveltitle(xplev);
        i:=randb(4)+1;
        hp:=hp+i; hpmax:=hpmax+i; showhp;
        i:=randb(4)+1;
        sp:=sp+i; spmax:=spmax+i; showsp;
        locate(23,1); writeln
    end;
end;

procedure Fight;
begin
    write('The ',creature[monster[x,y]],' ');
    if(hpweb<=0)then
        if(randb(100)<=m2hit[monster[x,y]]-armprot[gotarmor])then begin
            Hit; writeln(' you.');
            hp:=hp-randb(mdmg[monster[x,y]]);
            if(hp<0)then hp:=0;
            showhp;
            locate(23,1); writeln;
            dead:=(hp=0);
        end else begin
            missed; writeln(' you.');
    end else if(randb(100)<=m2hit[monster[x,y]]-20)then begin
        writeln('tears at the webs holding it.');
        hpweb:=hpweb-randb(mdmg[monster[x,y]]);
        if(hpweb<=0)then writeln('The ',creature[monster[x,y]],' broke free!');
    end else writeln('struggles to remove the entangling webs.');
end;

procedure move(there:integer);
var dx,dy:integer;
begin
    dx:=0; dy:=0; moved:=false;
    case there of
        274{up-arrow}:if(y>1)then if(map[x,y]<>map[x,y-1])then begin
            dy:=-1; moved:=true; writeln('You moved north.'); end;
        275{down-arrow}:if(y<N)then if(map[x,y]<>map[x,y+1])then begin
            dy:=+1; moved:=true; writeln('You moved south.'); end;
        277{right-arrow}:if(x<N)then if(map[x,y]<>map[x+1,y])then begin
            dx:=+1; moved:=true; writeln('You moved east.'); end;
        276{left-arrow}:if(x>1)then if(map[x,y]<>map[x-1,y])then begin
            dx:=-1; moved:=true; writeln('You moved west.'); end;
        62{>}:if(rooms[x,y]=ladder)then begin
            if(level=targetlev)then
                write('You can descend no further.  ')
            else if gotshred then
                writeln('This is a one-way ladder -- up!')
            else begin level:=level+1; moved:=true; samelev:=false;
                writeln('You descend further into the depths.');
            end
        end else write('There is no ladder here.  ');
        60{<}:if(rooms[x,y]=ladder)then
            if not(gotshred)then writeln('You cannot go up ',
                'without the Shred of Truth.')
            else begin level:=level-1; moved:=true; samelev:=false;
                writeln('As you climb, you feel a quivering ',
                    'sensation in your gut.');
                if(level=0)then victorious:=true; end
            else write('You see no ladder.  ');
    end;
    if moved then begin
        if(monster[x,y]>0)then if(hpweb<=0)then begin
            writeln('As you fled, you were attacked!');
            Fight;
        end else writeln('As you fled, the ',creature[monster[x,y]],
            ' broke free!');
        if(there>127)then drawroom(dx,dy);
        hpweb:=0;
    end else writeln('You cannot go that way.');
end;

procedure listpotions;
var i,lines:integer;
begin
    lines:=0;
    for i:=1 to potkinds do begin
        lines:=lines+1;
        if(lines=8)then begin
            lines:=0;
            pauseline
        end;
        write(chr(96+i),') ');
        if(potfind[potgot[i]])then begin
            if(potamt[i]=1)then write('a potion')
            else write(potamt[i]:1,' potions');
            writeln(' of ',potionname[potgot[i]]);
        end else begin
            if(potamt[i]=1)then begin
                if(color[potclr[potgot[i]]].body[1] in vowels)
                then write('an ')
                else write('a ');
                writeln(color[potclr[potgot[i]]],' potion');
            end else writeln(potamt[i]:1,' ',
                color[potclr[potgot[i]]],' potions');
        end
    end;
end;

procedure listscrolls;
var i,lines:integer;
begin
    lines:=0;
    for i:=1 to scrkinds do begin
        lines:=lines+1;
        if(lines=8)then begin
            lines:=0;
            pauseline
        end;
        write(chr(96+i),') ');
        if(scramt[i]=1)then write('a scroll')
        else write(scramt[i]:1,' scrolls');
        if spellknow[scrgot[i]]
        then writeln(' of ',spellname[scrgot[i]])
        else writeln(' called ',spellcall[spelltran[scrgot[i]]])
    end;
end;

procedure dotask(command:integer);
var i,j,drink,dx,dy,lines,spell,throw:integer;
    found:boolean;
begin
    drink:=0; spell:=0; throw:=0;
    case command of
    99{c}:
        if(spellsknown=0)then writeln('You know no spells to cast.')
        else begin
            writeln('You know the following spells:');
            lines:=0;
            for i:=1 to spellsknown do begin
                lines:=lines+1;
                if(lines=8)then begin lines:=0; pauseline end;
                writeln(chr(i+96),') ',spellname[spellgot[i]])
            end;
            writeln('Which spell will you cast?');
            j:=readletter-96;
            if(j<1)or(j>spellsknown)then
                writeln('You decide not to cast a spell.')
            else if(spellcost[spellgot[j]]>sp)then
                writeln('You are too weak to cast ',spellname[spellgot[j]],'.')
            else begin
                spell:=spellgot[j];
                sp:=sp-spellcost[spell];
                showsp;
                locate(23,1); writeln
            end
        end;
    101{e}:
        if food=0 then
            writeln('You have no food to eat.')
        else begin
            food:=food-1;
            locate(4,N*3+17); write(food:1,' ');
            locate(24,1);
            writeln('You ate a food ration.');
            hunger:=0;
        end;
    102{f}:begin
        if(monster[x,y]=0)then begin
            if(rooms[x,y]<>vendor)then writeln('Fighting shadows?')
        end else if(monster[x,y]>0)then
        if((randb(100)+4*xplev+20*ord(hpweb>0))>=m2bhit[monster[x,y]])
        then begin
            write('You '); Hit;
            writeln(' the ',creature[monster[x,y]],'.');
            mhp[x,y]:=mhp[x,y]-randb(weapdmg[gotweapon])-(xplev div 6);
        end else begin
            write('You '); missed;
            writeln(' the ',creature[monster[x,y]],'.')
        end;
        if(rooms[x,y]=vendor)then
        if(monster[x,y]>0)then begin
            writeln('The vendor says, "Allow me," and pulls out a ',
                'pulsed laser rifle in the 40 watt');
            writeln('range and obliterates the ',creature[monster[x,y]],'.');
            monster[x,y]:=0;
        end else begin
            writeln('Your blows are stopped in midair.  ',
                'It would seem that the vendor has access to');
            writeln('a protection from adventurers spell.  The vendor yawns.');
        end;
    end;
    63{?}:begin
        writeln('You pause as you recall the commands.');
        writeln(' movement: up-arrow=north, down-arrow=south, ',
            'right-arrow=east, left-arrow=west,');
        writeln('  <=up, >=down');
        writeln(' spells: c=cast spell, l=learn scroll, r=read scroll');
        writeln(' potions: d=drink, t=throw');
        writeln(' miscellaneous: q=quit, v=version, x=redraw screen, ',
            '?=help, m=map symbols,');
        writeln('  o=output saved game, i=input saved game, e=eat food,');
        writeln('  z=select save file, $=trade with a vendor');
    end;
    109{m}:begin
        writeln('You pause to decipher your map.');
        writeln(' ',clear,'  normal room');
        writeln(' ',shred,'  Shred of Truth');
        writeln(' ',vendor,'  vendor');
        writeln(' ',ladder,'  ladder');
        writeln(' ',ration,'  food ration');
    end;
    105{i}:begin
        getsave;
        drawdisplay
    end;
    108{l}:
        if(scrkinds=0)then
            writeln('You have no scrolls to learn from.')
        else if(spellsknown=maxspells[race])then
            writeln('You cannot learn another spell.')
        else begin
            writeln('You can learn a spell from the following:');
            listscrolls;
            writeln('Which spell will you learn?');
            j:=readletter-96;
            if(j<1)or(j>scrkinds)then
                writeln('You decide not to learn a spell.')
            else if(spellcost[scrgot[j]]>spmax)then
                writeln('The spell is too complex to learn.')
            else begin
                found:=false;
                for i:=1 to spellsknown do
                    if(scrgot[j]=spellgot[i])then found:=true;
                if found then
                    writeln('You already know it.')
                else begin
                    writeln('The scroll vanishes as you learn it.');
                    scramt[j]:=scramt[j]-1;
                    spellsknown:=spellsknown+1;
                    locate(13,N*3+17);
                    write(spellsknown:1);
                    locate(23,1); writeln;
                    spellgot[spellsknown]:=scrgot[j];
                    if not(spellknow[scrgot[j]])then begin
                        spellknow[scrgot[j]]:=true;
                        writeln('You now can cast ',spellname[scrgot[j]],'.')
                    end;
                    if(scramt[j]=0)then begin
                        scrkinds:=scrkinds-1;
                        for i:=j to scrkinds do begin
                            scrgot[i]:=scrgot[i+1];
                            scramt[i]:=scramt[i+1]
                        end
                    end
                end
            end
        end;
    111{o}:begin
        putsave;
        writeln('Saved as: ',savespec);
    end;
    100{d}:begin
        if(potkinds=0)then
            writeln('You have no potions to drink.')
        else begin
            writeln('You have:');
            listpotions;
            writeln('Which potion will you drink?');
            j:=readletter-96;
            if(j<1)or(j>potkinds)then
                writeln('You decide not to drink a potion.')
            else begin
                potamt[j]:=potamt[j]-1;
                drink:=potgot[j];
                if(potamt[j]=0)then begin
                    potkinds:=potkinds-1;
                    for i:=j to potkinds do begin
                        potgot[i]:=potgot[i+1];
                        potamt[i]:=potamt[i+1]
                    end
                end
            end
        end
    end;
    113{q}:begin
        writeln('Do you really want to quit (y/n)?');
        i:=readletter-96;
        if i=25 then begin quit:=true; dead:=true end
    end;
    114{r}:begin
        if(scrkinds=0)then
            writeln('You have no scrolls to read.')
        else begin
            writeln('You have:'); listscrolls;
            writeln('Which scroll will you read?');
            j:=readletter-96;
            if(j<1)or(j>scrkinds)then
                writeln('You decide not to read a scroll.')
            else begin
                scramt[j]:=scramt[j]-1;
                spell:=scrgot[j];
                spellknow[spell]:=true;
                if(scramt[j]=0)then begin
                    scrkinds:=scrkinds-1;
                    for i:=j to scrkinds do begin
                        scrgot[i]:=scrgot[i+1];
                        scramt[i]:=scramt[i+1]
                    end
                end
            end
        end
    end;
    116{t}:if(potkinds=0)then writeln('You have no potions to throw.')
    else begin
        writeln('You have:');
        listpotions;
        writeln('Which potion will you throw?');
        j:=readletter-96;
        if(j<1)or(j>potkinds)then
            writeln('You decide not to throw a potion.')
        else begin
            potamt[j]:=potamt[j]-1;
            throw:=potgot[j];
            if(potamt[j]=0)then begin
                potkinds:=potkinds-1;
                for i:=j to potkinds do begin
                    potgot[i]:=potgot[i+1];
                    potamt[i]:=potamt[i+1]
                end
            end
        end
    end;
    118{v}:writeln('Quest for the Shred of Truth ',version);
    120{x}:drawdisplay;
    122{z}:begin
        writeln('Current save file: ',savespec);
        write('Enter new save file: ');
        readln(savespec);
        writeln('Current save file: ',savespec)
    end;
    36{$}:
        if rooms[x,y]=vendor then
            runvend
        else
            writeln('I see no vendor.  Having hallucinations?');
    otherwise writeln('You pause, wondering what the commands are.')
    end;
    if(spell>0)then case spell of
        1:begin
            writeln('A fireball erupts from your fingertips.');
            if(monster[x,y]<>0)then begin
                writeln('It flies toward the ',creature[monster[x,y]],
                    ' and explodes!');
                mhp[x,y]:=mhp[x,y]-rand2(6,6);
                if(hpweb>0)then begin
                    writeln('The webs are burning with glee!');
                    mhp[x,y]:=mhp[x,y]-hpweb*2;
                    hpweb:=0
                end
            end else if rooms[x,y]<>vendor then
                writeln('It dissipates harmlessly.')
            else begin
                writeln('As the crisp hulk that once was a vendor ',
                    'falls to the floor, another steps');
                writeln('forward and says, "Thanks for getting rid ',
                    'of competition.  Wanna trade?"');
            end;
        end;
        2:begin
            writeln('You begin to feel better.');
            if(hp<hpmax)then begin
                hp:=hp+randb(8);
                if(hp>hpmax)then hp:=hpmax;
                showhp;
                locate(23,1); writeln
            end
        end;
        3:begin
            writeln('A magic missile shoots forth.');
            if(monster[x,y]>0)then begin
                writeln('It strikes the ',creature[monster[x,y]],'!');
                mhp[x,y]:=mhp[x,y]-rand2(2,4)
            end else if rooms[x,y]<>vendor then
                writeln('It strikes the wall and vanishes.')
            else writeln('The vendor dispels the missile with ',
                'a snap of his fingers.');
        end;
        4:begin
            writeln('You are teleported to another room.');
            dx:=0; dy:=0; hpweb:=0;
            repeat dx:=randb(N)-x; dy:=randb(N)-y until(dx<>0)and(dy<>0);
            drawroom(dx,dy);
            if(monster[x,y]>0)or(rooms[x,y]=vendor)then begin
                writeln('However, it seems the room is already occupied.');
                warn;
            end
        end;
        5:if(monster[x,y]>0)then begin
            writeln('The ',creature[monster[x,y]],
                ' collapses as you steal its vitality.');
            writeln('You feel its energy flow into your ',
                'being.  (Not a pleasant thought.)');
            hp:=hp+(mhp[x,y] div 2);
            sp:=sp+(mhp[x,y] div 2);
            mhp[x,y]:=0;
            showhp; showsp;
            locate(23,1); writeln
        end else if rooms[x,y]<>vendor then
            writeln('You feel a vague thirst.')
        else writeln('No effect.  Perhaps vendors are soulless creatures.');
        6:begin
            writeln('Webs spew forth from your hands.');
            if(monster[x,y]>0)then begin
                hpweb:=hpweb+(spmax div 10)+rand2(3,6);
                writeln('They entangle the ',creature[monster[x,y]],'!')
            end else if rooms[x,y]=vendor then begin
                writeln('They strike the vendor and fall about his ',
                    'feet.  He gives you a puzzled look.');
                writeln('"Why did you do that?"');
            end else writeln('They dissolve and fade away.');
        end;
        7:if rooms[x,y]=vendor then
            writeln('A vendor is already here.  I guess the spell worked.')
        else if rooms[x,y]<>clear then
            writeln('Nothing happens.  You notice a "no vendors" sign on ',
                'a wall.')
        else begin
            writeln('In the distance, you hear the alien "beep-beep" of a ',
                'paging device.');
            rooms[x,y]:=vendor;
            drawroom(0,0);
            writeln('A vendor appears seemingly out of nowhere and says, ',
                '"You called?"');
        end;
        8:if rooms[x,y]=ladder then
            writeln('A ladder is already here.  I guess the spell worked.')
        else if rooms[x,y]=shred then begin
            writeln('Section 12, subsection 6, paragraph 54, ',
                'subparagraph 9, footnote 5 of the');
            writeln('Dungeon Construction Guide specifically prohibits ',
                'the creation of ladders');
            writeln('where magical shreds are being guarded.')
        end else begin
            if rooms[x,y]=vendor then
                writeln('The vendor screams in terror and flees.  ',
                    'Very odd, to say the least.');
            rooms[x,y]:=ladder;
            drawroom(0,0);
            writeln('A ladder appears out of nowhere.');
            if monster[x,y]>0 then begin
                writeln('The ',creature[monster[x,y]],
                    ' appears insulted at it is gored by the ladder.');
                mhp[x,y]:=0
            end;
        end;
        9:if(scrkinds=0)then writeln('You have no scrolls to identify.')
        else begin
            writeln('You have:'); listscrolls;
            writeln('Which scroll will you identify?');
            j:=readletter-96;
            if(j<1)or(j>scrkinds)then writeln('You have no such scroll.')
            else begin
                spellknow[scrgot[j]]:=true;
                writeln('The scroll is of ',spellname[scrgot[j]],'.')
            end;
        end;
        10:if(potkinds=0)then writeln('You have no potions to identify.')
        else begin
            writeln('You have:'); listpotions;
            writeln('Which potion will you identify?');
            j:=readletter-96;
            if(j<1)or(j>potkinds)then writeln('You have no such potion.')
            else begin
                potfind[potgot[j]]:=true;
                writeln('The vial contains a potion of ',
                    potionname[potgot[j]],'.');
            end;
        end;
        11:begin
            writeln('Nothing happens.');
        end;
        12:begin
            writeln('A map appears in your mind, allowing you to see ',
                'the entire level.');
            for i:=1 to n do for j:=1 to n do visited[i,j]:=true;
            newmap;
        end;
        13:if monster[x,y]>0 then
            writeln('A monster is already here.  I guess the spell worked.')
        else begin
            writeln('You are momentarily blinded by a flash of light.');
            monster[x,y]:=getmonster(level);
            mhp[x,y]:=mhps[monster[x,y]];
            warn
        end;
    end{case};
    if(throw>0)then begin
        if potfind[throw] then
            writeln('You threw a potion of ',potionname[throw],'.')
        else begin
            write('You threw a');
            if color[potclr[throw]].body[1] in vowels then write('n');
            writeln(' ',color[potclr[throw]],' potion.')
        end;
        if monster[x,y]>0 then begin
            writeln('The flask broke as it hit the ',
                creature[monster[x,y]],'.');
            found:=false;
            case throw of
            1:begin
                writeln('The potion heals the wounds caused ',
                    'by the broken glass.');
                found:=true;
            end;
            2:begin
                writeln('The potion heals the wounds caused ',
                    'by the broken glass.  However, you');
                writeln('notice the ',creature[monster[x,y]],
                    ' seems somewhat stronger.');
                mhp[x,y]:=mhp[x,y]+1;
                found:=true;
            end;
            3:begin
                writeln('The ',creature[monster[x,y]],
                    ' seems somewhat weakened.');
                mhp[x,y]:=mhp[x,y]-1-randb(8);
                if mhp[x,y]<=0 then writeln('It collapses and dies,',
                    ' a victim of contaminated potions.');
                found:=true;
            end;
            5:begin
                writeln('Uh oh.  The ',creature[monster[x,y]],
                    ' seems as good as new.');
                mhp[x,y]:=mhps[monster[x,y]];
                found:=true;
            end;
            7:begin
                writeln('Ah!  The ',creature[monster[x,y]],
                    ' staggers visibly.');
                mhp[x,y]:=mhp[x,y]div 2;
                found:=true;
            end;
            otherwise begin
                writeln('The ',creature[monster[x,y]],
                    ' is slightly hurt by the glass shards.');
                mhp[x,y]:=mhp[x,y]-1;
            end;
            end{case};
            if found and not potfind[throw] then begin
                potfind[throw]:=true;
                writeln('You threw a potion of ',potionname[throw],'.');
            end;
        end else begin
            writeln('The flask shatters against the wall.  A janitor ',
                'rushes in, cleans up the mess,');
            writeln('frowns at you, and vanishes.')
        end
    end else if(drink>0)then begin
        writeln('You drank a potion of ',potionname[drink],'.');
        potfind[drink]:=true;
        case drink of
        1:begin
            if(hp>=hpmax)then begin
                hpmax:=hpmax+1; hp:=hp+1
            end else begin
                hp:=hp+randb(8)+1;
                if(hp>hpmax)then hp:=hpmax
            end;
            showhp;
        end;
        2:begin
            if(hp>=hpmax)then begin
                hpmax:=hpmax+2; hp:=hp+2
            end else begin
                hp:=hp+Rand2(3,8)+2;
                if(hp>hpmax)then hp:=hpmax
            end;
            showhp;
        end;
        3:begin
            hp:=hp-randb(8);
            if(hp<0)then hp:=0;
            showhp;
            dead:=(hp=0)
        end;
        4:begin
            if(sp>=spmax)then begin
                spmax:=spmax+3; sp:=sp+3
            end else begin
                sp:=sp+Rand2(3,8)+2;
                if(sp>spmax)then sp:=spmax
            end;
            showsp;
        end;
        5:begin
            writeln('You feel as good as new!');
            if(hp<hpmax)then begin
                hp:=hpmax;
                showhp
            end
        end;
        6:begin
            writeln('Your mind feels clear and sharp!');
            if(sp<spmax)then begin
                sp:=spmax;
                showsp;
            end
        end;
        7:begin
            writeln('You feel sick to your stomach!');
            hp:=(hp+1)div 2;
            showhp;
        end;
        8:begin
            writeln('Your head pounds horribly!');
            sp:=(sp+1)div 2;
            showsp;
        end;
        9:begin
            writeln('You feel more skillful!');
            xp:=xp+499+randb(100);
            locate(9,N*3+22);
            writeln(xp:1);
            advancelevel
        end;
        10:writeln('It tasted a lot like a soft drink, ',
            'whatever that is.  You belch for a while.');
        11:begin
            writeln('It tasted a lot like an instant breakfast.');
            hunger:=0
        end;
        12:begin
            writeln('Odd.  You feel much hungrier.');
            hunger:=hunger+200;
        end;
        end{case};
        locate(23,1); writeln;
    end;
    if(mhp[x,y]<=0)and(monster[x,y]>0)then begin
        writeln('You have defeated the ',creature[monster[x,y]],'.');
        kills:=kills+1;
        locate(7,N*3+22);
        writeln(kills:1);
        xp:=xp+mxp[monster[x,y]];
        locate(9,N*3+22); write(xp:1);
        locate(23,1); writeln;
        advancelevel;
        if(rooms[x,y]=shred)and(not gotshred)then begin
            writeln('You now have the Shred of Truth!');
            rooms[x,y]:=clear;
            drawroom(0,0);
            gotshred:=true
        end;
        if(mtraits[monster[x,y]]>=[gold])then if(randb(100)<=75)then begin
            writeln('You have found some gold.');
            gp:=gp+Rand2(monster[x,y]+2*level,20);
            locate(3,N*3+16); write(gp:1);
            locate(23,1); writeln
        end;
        if(mtraits[monster[x,y]]>=[potion])then if(randb(100)<=50)then begin
            writeln('You found a potion.');
            i:=getpotion;
            found:=false;
            for j:=1 to potkinds do if(potgot[j]=i)then begin
                found:=true;
                potamt[j]:=potamt[j]+1
            end;
            if(not found)then begin
                potkinds:=potkinds+1;
                potgot[potkinds]:=i;
                potamt[potkinds]:=1
            end
        end;
        if(mtraits[monster[x,y]]>=[scroll])then if(randb(100)<=50)then begin
            writeln('You found a scroll.');
            i:=getscroll;
            found:=false;
            for j:=1 to scrkinds do if(scrgot[j]=i)then begin
                found:=true;
                scramt[j]:=scramt[j]+1
            end;
            if(not found)then begin
                scrkinds:=scrkinds+1;
                scrgot[scrkinds]:=i;
                scramt[scrkinds]:=1
            end
        end;
        monster[x,y]:=0
    end;
end;

procedure PlayGame;
var q:integer;
begin
    repeat
        if not samelev then begin
            locate(1,N*3+18); writeln(level:1);
            locate(23,1); writeln;
            initlevel;
            moved:=true; samelev:=true;
        end;
        repeat
            if(moved and(monster[x,y]=0))then
                if(randb(100)<=10)then begin
                    monster[x,y]:=getmonster(level);
                    mhp[x,y]:=mhps[monster[x,y]];
                end;
            if moved then begin
                hpweb:=0;
                moved:=false;
                if(monster[x,y]>0)then begin
                    Warn;
                    if(randb(2)=1)then Fight
                end
            end else if(monster[x,y]>0)then Fight;
            if(rooms[x,y]=ration)and(monster[x,y]=0)
            then begin
                rooms[x,y]:=clear;
                drawroom(0,0);
                food:=food+1;
                locate(4,N*3+17); write(food:1);
                locate(24,1);
                writeln('You take the food from the room.')
            end;
            hunger:=hunger+1;
            if hunger>=300 then begin
                writeln('You pass out from lack of food.  ',
                    'As you sleep, you are mugged.');
                if gotarmor>1 then begin
                    writeln('When you wake, you find your armor is gone.');
                    gotarmor:=1;
                    locate(8,N*3+33);
                    write(armorname[gotarmor],esc,'[K')
                end else begin
                    writeln('You suffered some damage from a concussion.');
                    hp:=hp-randb(8); if hp<0 then hp:=0;
                    showhp;
                    dead:=(hp=0);
                end;
                locate(23,1); writeln;
                hunger:=100;
            end else if hunger>=250 then
                writeln('You are ravenously hungry.')
            else if hunger>=200 then
                writeln('You are very hungry.')
            else if hunger>=150 then
                writeln('You are hungry.');
            if(not dead)then begin
                locate(23,1); writeln;
                q:=readletter;
                if((q>=274)and(q<=277))or((q=60)or(q=62))
                then move(q)else dotask(q);
            end
        until(dead or victorious)or(not samelev);
    until(dead or victorious)
end;

procedure makeplayer;
var i,j,k:integer;
begin
    for i:=1 to potions do begin
        potfind[i]:=false; potclr[i]:=i
    end;
    for i:=1 to(potions-1)do begin
        j:=randb(potions-i+1)+i-1;
        k:=potclr[i]; potclr[i]:=potclr[j]; potclr[j]:=k
    end;
    for i:=1 to spells do begin
        spellknow[i]:=false; spelltran[i]:=i
    end;
    for i:=1 to(spells-1)do begin
        j:=randb(spells-i+1)+i-1;
        k:=spelltran[i]; spelltran[i]:=spelltran[j]; spelltran[j]:=k
    end;
    write('What will you call your character? ');
    readln(name); writeln;
    repeat
        writeln;
        writeln('What race will your character be?');
        for i:=1 to races do writeln(chr(96+i),') ',racename[i]);
        race:=readletter-96;
        if(race<0)or(race>races)then race:=0;
        if race=0 then writeln('Pick one from the list.')
    until race>0;
    writeln('Race: ',racename[race]);
    hpmax:=rhp[race]; spmax:=rsp[race];
    if(race=6)or(race=5)then begin
        spellsknown:=1;
        repeat spellgot[1]:=getscroll
        until spellcost[spellgot[1]]<=spmax;
        spellknow[spellgot[1]]:=true;
        writeln('You know a ',spellname[spellgot[1]],' spell.');
    end;
    hp:=hpmax; sp:=spmax;
    writeln;
    gp:=43+randb(42);
    writeln('You leave for the dungeons with ',gp:1,' gold pieces.');
    writeln('At the entrance to the dungeon, you encounter a vendor.');
    writeln;
    repeat gotarmor:=buyarmor(1) until gotarmor>0;
    writeln;
    repeat gotweapon:=buyweapon(1) until gotweapon>0;
    writeln;
    writeln('You have ',gp:1,' gp.');
    writeln('Demons believed to have originiated from the dungeons of a ');
    writeln('university have stolen the Shred of Truth and hidden it.');
    writeln('You must seek out the Shred of Truth and rescue it.');
    writeln('The help command is "?".  Press return to begin your quest.');
    repeat i:=readletter until i=13;
    kills:=0; xp:=0; xplev:=0; food:=1; hunger:=0;
    nextlev:=500;
    level:=1; levels:=0;
    dead:=false;
    quit:=false;
    victorious:=false;
    gotshred:=false
end;

begin{main}
    title[0]:='Novice';
    title[1]:='Apprentice';
    title[2]:='Journeyman';
    title[3]:='Fighter';
    title[4]:='Warrior';
    title[5]:='Hero';
    title[6]:='Champion';
    title[7]:='Knight';
    title[8]:='Warlord';
    title[9]:='Dragonslayer';
    title[10]:='Dragonmaster';
    title[11]:='Dragonlord';
    title[12]:='Dragon Knight';
    title[13]:='Hero of the Realm';
    title[14]:='Champion of the Realm';
    title[15]:='Earl';
    title[16]:='Baron';
    title[17]:='Duke';
    title[18]:='Prince';
    title[19]:='High King';
    title[20]:='Savior of the Realm';
    color[1]:='blue';
    color[2]:='crimson';
    color[3]:='green';
    color[4]:='orange';
    color[5]:='clear';
    color[6]:='yellow';
    color[7]:='pink';
    color[8]:='plaid';
    color[9]:='violet';
    color[10]:='brown';
    color[11]:='black';
    color[12]:='white';
    potionname[1]:='healing';
    potionname[2]:='extra healing';
    potionname[3]:='poison';
    potionname[4]:='mental fortitude';
    potionname[5]:='bodily regeneration';
    potionname[6]:='mental regeneration';
    potionname[7]:='bodily feebleness';
    potionname[8]:='mental feebleness';
    potionname[9]:='experience';
    potionname[10]:='thirst quenching';
    potionname[11]:='hunger quenching';
    potionname[12]:='hunger';
    armorname[1]:='no armor'; gparm[1]:=0; armprot[1]:=0;
    armorname[2]:='leather armor'; gparm[2]:=12; armprot[2]:=10;
    armorname[3]:='ring mail'; gparm[3]:=18; armprot[3]:=15;
    armorname[4]:='scale mail'; gparm[4]:=24; armprot[4]:=20;
    armorname[5]:='chain mail'; gparm[5]:=30; armprot[5]:=25;
    armorname[6]:='splint mail'; gparm[6]:=36; armprot[6]:=30;
    armorname[7]:='plate mail'; gparm[7]:=42; armprot[7]:=35;
    armorname[8]:='full plate armor'; gparm[8]:=54; armprot[8]:=45;
    armorname[9]:='Dyflex hard body armor'; gparm[9]:=72; armprot[9]:=60;
    racename[1]:='human'; rhp[1]:=40; rsp[1]:=50; maxspells[1]:=6;
    racename[2]:='elf'; rhp[2]:=30; rsp[2]:=100; maxspells[2]:=8;
    racename[3]:='dwarf'; rhp[3]:=50; rsp[3]:=25; maxspells[3]:=3;
    racename[4]:='Melnibonean'; rhp[4]:=40; rsp[4]:=75; maxspells[4]:=8;
    racename[5]:='sorcerer-king'; rhp[5]:=90; rsp[5]:=200; maxspells[5]:=10;
    racename[6]:='wizard'; rhp[6]:=25; rsp[6]:=300; maxspells[6]:=spells;
    racename[7]:='barbarian'; rhp[7]:=200; rsp[7]:=20; maxspells[7]:=3;
    racename[8]:='Pee-Wee Herman'; rhp[8]:=10; rsp[8]:=5; maxspells[8]:=1;
    spellcall[1]:='krakatoa';
    spellcall[2]:='wrackle';
    spellcall[3]:='watizdis';
    spellcall[4]:='zapdare';
    spellcall[5]:='ack-ack';
    spellcall[6]:='wizfizz';
    spellcall[7]:='abradabradu';
    spellcall[8]:='joez-bar';
    spellcall[9]:='gurgle';
    spellcall[10]:='pleeb';
    spellcall[11]:='axwit-ai';
    spellcall[12]:='xoomvec';
    spellcall[13]:='ach-no';
    spellname[1]:='fireball'; spellcost[1]:=23;
    spellname[2]:='healing'; spellcost[2]:=9;
    spellname[3]:='magic missile'; spellcost[3]:=5;
    spellname[4]:='teleport'; spellcost[4]:=12;
    spellname[5]:='steal life'; spellcost[5]:=49;
    spellname[6]:='web'; spellcost[6]:=16;
    spellname[7]:='summon vendor'; spellcost[7]:=15;
    spellname[8]:='create ladder'; spellcost[8]:=131;
    spellname[9]:='identify scroll'; spellcost[9]:=10;
    spellname[10]:='identify potion'; spellcost[10]:=10;
    spellname[11]:='blank paper'; spellcost[11]:=maxint;
    spellname[12]:='magic mapping'; spellcost[12]:=93;
    spellname[13]:='summon monster'; spellcost[13]:=maxint;
    weaponname[1]:='bare hands'; gpweap[1]:=0; weapdmg[1]:=2;
    weaponname[2]:='club'; gpweap[2]:=5; weapdmg[2]:=4;
    weaponname[3]:='dagger'; gpweap[3]:=10; weapdmg[3]:=6;
    weaponname[4]:='foil'; gpweap[4]:=15; weapdmg[4]:=8;
    weaponname[5]:='long sword'; gpweap[5]:=20; weapdmg[5]:=10;
    weaponname[6]:='two handed sword'; gpweap[6]:=30; weapdmg[6]:=12;
    weaponname[7]:='ion sabre'; gpweap[7]:=45; weapdmg[7]:=16;
    weaponname[8]:='phased ion sabre'; gpweap[8]:=60; weapdmg[8]:=20;
    weaponname[9]:='runesword'; gpweap[9]:=75; weapdmg[9]:=24;
           potkinds:=0; scrkinds:=0; spellsknown:=0;
    creature[1]:='crazed maniac';
    mhps[1]:=3; m2hit[1]:=50; m2bhit[1]:=50; mdmg[1]:=2; mxp[1]:=10;
    mtraits[1]:=[gold];
    creature[2]:='reckless loonie';
    mhps[2]:=6; m2hit[2]:=50; m2bhit[2]:=50; mdmg[2]:=3; mxp[2]:=20;
    mtraits[2]:=[gold,potion];
    creature[3]:='stupid alchemist';
    mhps[3]:=9; m2hit[3]:=55; m2bhit[3]:=50; mdmg[3]:=4; mxp[3]:=35;
    mtraits[3]:=[gold,potion,scroll];
    creature[4]:='psychopathic human adventurer';
    mhps[4]:=12; m2hit[4]:=55; m2bhit[4]:=55; mdmg[4]:=5; mxp[4]:=50;
    mtraits[4]:=[gold,potion,scroll];
    creature[5]:='novice dark elf adventurer';
    mhps[5]:=15; m2hit[5]:=60; m2bhit[5]:=55; mdmg[5]:=6; mxp[5]:=70;
    mtraits[5]:=[potion,scroll];
    creature[6]:='decomposing corpse';
    mhps[6]:=19; m2hit[6]:=60; m2bhit[6]:=55; mdmg[6]:=7; mxp[6]:=90;
    mtraits[6]:=[gold,potion,scroll];
    creature[7]:='lost minotaur';
    mhps[7]:=23; m2hit[7]:=65; m2bhit[7]:=60; mdmg[7]:=8; mxp[7]:=115;
    mtraits[7]:=[potion];
    creature[8]:='ferocious wrestler';
    mhps[8]:=40; m2hit[8]:=65; m2bhit[8]:=60; mdmg[8]:=9; mxp[8]:=170;
    mtraits[8]:=[gold,scroll];
    creature[9]:='dark elf warrior';
    mhps[9]:=27; m2hit[9]:=65; m2bhit[9]:=60; mdmg[9]:=9; mxp[9]:=140;
    mtraits[9]:=[gold,potion];
    creature[10]:='gargoyle';
    mhps[10]:=35; m2hit[10]:=70; m2bhit[10]:=60; mdmg[10]:=10;
    mxp[10]:=170; mtraits[10]:=[gold,scroll];
    creature[11]:='cavewight';
    mhps[11]:=40; m2hit[11]:=75; m2bhit[11]:=65; mdmg[11]:=11;
    mxp[11]:=200; mtraits[11]:=[gold,potion,scroll];
    creature[12]:='griffin';
    mhps[12]:=45; m2hit[12]:=75; m2bhit[12]:=65; mdmg[12]:=12;
    mxp[12]:=235; mtraits[12]:=[gold,potion,scroll];
    creature[13]:='troll';
    mhps[13]:=50; m2hit[13]:=80; m2bhit[13]:=70; mdmg[13]:=13;
    mxp[13]:=270; mtraits[13]:=[gold,potion,scroll];
    creature[14]:='dragonyn';
    mhps[14]:=55; m2hit[14]:=80; m2bhit[14]:=70; mdmg[14]:=14;
    mxp[14]:=310; mtraits[14]:=[gold,potion,scroll];
    creature[15]:='jabberwock';
    mhps[15]:=60; m2hit[15]:=85; m2bhit[15]:=70; mdmg[15]:=15;
    mxp[15]:=350; mtraits[15]:=[gold,potion,scroll];
    creature[16]:='hellrender';
    mhps[16]:=60; m2hit[16]:=85; m2bhit[16]:=70; mdmg[16]:=16;
    mxp[16]:=400; mtraits[16]:=[potion,scroll];
    creature[17]:='lesser demon';
    mhps[17]:=65; m2hit[17]:=85; m2bhit[17]:=75; mdmg[17]:=17;
    mxp[17]:=450; mtraits[17]:=[potion,scroll];
    creature[18]:='pit fiend';
    mhps[18]:=70; m2hit[18]:=85; m2bhit[18]:=75; mdmg[18]:=18;
    mxp[18]:=500; mtraits[18]:=[potion,scroll];
    creature[19]:='mist demon';
    mhps[19]:=75; m2hit[19]:=90; m2bhit[19]:=80; mdmg[16]:=19;
    mxp[19]:=550; mtraits[19]:=[potion,scroll];
    creature[20]:='greater demon';
    mhps[20]:=80; m2hit[20]:=90; m2bhit[20]:=85; mdmg[20]:=20;
    mxp[20]:=600; mtraits[20]:=[potion,scroll];
    gp:=randb(0); {initialize random numbers}
    cls; window(1,24); locate(1,1);
    samelev:=false;
    keyboard:=0;
    smg$create_virtual_keyboard(keyboard);
    if cli$present('FILESPEC') then begin
        cli$get_value('FILESPEC',savespec.body,savespec.length);
        getsave;
        drawdisplay;
        writeln('Continuing game saved in: ',savespec);
        write('Welcome back ')
    end else begin
        makeplayer;
        savespec:='safe.jny';
        drawscreen;
        write('Welcome ')
    end;
    writeln('to the dungeons.');
    playgame;
    if dead then writeln('You have failed in your quest.');
    if quit then writeln('Quitter.');
    if victorious then begin
        writeln('You have rescued the Shred of Truth!');
        writeln('You emerge from the dungeons victorious!');
    end;
    writeln;
    window(1,24); locate(23,1)
end{main}.
