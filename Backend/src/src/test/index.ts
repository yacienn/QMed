
interface userr {
    name: string ;
    age: number;
    games: games[];
}
interface games{
    id: number;
    name: string ;
}
const room = new Map<string , userr>();

const game: games ={
    id: 12 ,
    name :"pubg"
}
console.log(game)
const p: userr= {
    name: "Yacine",
    age: 14 ,
    games: [game],
}

room.set("A" , p);
const r = room.get("A");
if(r){
 console.log(r.games[0]?.name);
}

