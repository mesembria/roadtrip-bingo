#!/usr/bin/env swift
// Run once: swift makeSquares.swift > RoadTripBingo/Resources/squares.json
// Commit the result — do not regenerate or existing square IDs will change.

import Foundation

struct S: Encodable {
    let id: String; let text: String; let emoji: String; let category: String
}
func s(_ text: String, _ emoji: String, _ cat: String) -> S {
    S(id: UUID().uuidString, text: text, emoji: emoji, category: cat)
}

let squares: [S] = [
    // Vehicles (25)
    s("Semi Truck","🚛","vehicles"), s("RV","🚐","vehicles"), s("Motorcycle","🏍️","vehicles"),
    s("School Bus","🚌","vehicles"), s("Tractor","🚜","vehicles"), s("Pickup Truck","🛻","vehicles"),
    s("Police Car","🚔","vehicles"), s("Fire Truck","🚒","vehicles"), s("Helicopter","🚁","vehicles"),
    s("Small Plane","✈️","vehicles"), s("Horse Trailer","🐴","vehicles"), s("Flatbed Truck","🚚","vehicles"),
    s("Dump Truck","🚧","vehicles"), s("Ambulance","🚑","vehicles"), s("Convertible","🚗","vehicles"),
    s("Food Truck","🌮","vehicles"), s("Mail Truck","📦","vehicles"), s("Boat on Trailer","⛵","vehicles"),
    s("Construction Vehicle","🏗️","vehicles"), s("Tow Truck","🔧","vehicles"),
    s("Double-Decker Bus","🚌","vehicles"), s("Minivan","🚐","vehicles"), s("Sports Car","🏎️","vehicles"),
    s("Ice Cream Truck","🍦","vehicles"), s("Tank Truck","🛢️","vehicles"),
    // Nature (25)
    s("Cow","🐄","nature"), s("Horse","🐎","nature"), s("Deer","🦌","nature"),
    s("Red Barn","🏚️","nature"), s("Sunflower Field","🌻","nature"), s("Hay Bale","🌾","nature"),
    s("Wind Turbine","💨","nature"), s("Mountain","🏔️","nature"), s("River","🌊","nature"),
    s("Lake","🏞️","nature"), s("Rainbow","🌈","nature"), s("Double Rainbow","🌈","nature"),
    s("Cactus","🌵","nature"), s("Cornfield","🌽","nature"), s("Orchard","🍎","nature"),
    s("Flock of Birds","🐦","nature"), s("Goat","🐐","nature"), s("Sheep","🐑","nature"),
    s("Pig","🐷","nature"), s("Dog in Car Window","🐶","nature"), s("Wildflowers","💐","nature"),
    s("Waterfall","💦","nature"), s("Vineyard","🍇","nature"), s("Buffalo","🦬","nature"),
    s("Hawk","🦅","nature"),
    // Food & Stops (25)
    s("McDonald's","🍟","food"), s("Starbucks","☕","food"), s("Subway","🥖","food"),
    s("Gas Station","⛽","food"), s("Rest Stop","🅿️","food"), s("Drive-Through","🚗","food"),
    s("Billboard","📢","food"), s("Roadside Diner","🍽️","food"), s("Fruit Stand","🍑","food"),
    s("Ice Cream Stand","🍦","food"), s("Wendy's","🍔","food"), s("Taco Bell","🌮","food"),
    s("Chick-fil-A","🐔","food"), s("Dairy Queen","🍦","food"), s("Cracker Barrel","🪑","food"),
    s("Waffle House","🧇","food"), s("Truck Stop","🚛","food"), s("Car Wash","🚿","food"),
    s("Motel Sign","🏨","food"), s("Campground Sign","⛺","food"), s("Dollar General","💵","food"),
    s("Fireworks Stand","🎆","food"), s("Roadside BBQ","🍖","food"), s("RV Park","🏕️","food"),
    s("Outlet Mall","🛍️","food"),
    // Landmarks (25)
    s("Bridge","🌉","landmarks"), s("Overpass","🛣️","landmarks"), s("Railroad Crossing","🚂","landmarks"),
    s("State Border Sign","🪧","landmarks"), s("Toll Booth","💰","landmarks"),
    s("Welcome Sign","👋","landmarks"), s("Water Tower","🏗️","landmarks"),
    s("Church Steeple","⛪","landmarks"), s("Grain Silo","🏠","landmarks"),
    s("Sports Stadium","🏟️","landmarks"), s("Fairground","🎡","landmarks"),
    s("State Capitol","🏛️","landmarks"), s("Wind Farm","🌬️","landmarks"),
    s("Solar Farm","☀️","landmarks"), s("Airport","✈️","landmarks"), s("Radio Tower","📡","landmarks"),
    s("Drive-In Theater","🎬","landmarks"), s("Covered Bridge","🌉","landmarks"),
    s("Lighthouse","🗼","landmarks"), s("National Park Sign","🌲","landmarks"),
    s("Monument","🗿","landmarks"), s("Dam","🌊","landmarks"), s("Ghost Town","👻","landmarks"),
    s("Roadside Attraction","⭐","landmarks"), s("Mining Facility","⛏️","landmarks"),
    // Weather (25)
    s("Dark Clouds","☁️","weather"), s("Fog","🌫️","weather"), s("Dust Storm","🌪️","weather"),
    s("Snow on Mountains","❄️","weather"), s("Puddles","💧","weather"), s("Sun Glare","☀️","weather"),
    s("Thunderstorm","⛈️","weather"), s("Lightning","⚡","weather"), s("Hail","🌨️","weather"),
    s("Tornado Warning Sign","🌪️","weather"), s("Mirage","🏜️","weather"),
    s("Dramatic Sunset","🌅","weather"), s("Low-Hanging Moon","🌕","weather"),
    s("Stars Visible","⭐","weather"), s("Hot Haze Shimmer","🌡️","weather"),
    s("Wildfire Smoke","🔥","weather"), s("Dust Devil","🌀","weather"),
    s("Ice on Road Sign","🧊","weather"), s("Flash Flood Sign","🌊","weather"),
    s("Overcast Sky","🌥️","weather"), s("Sprinkles","🌦️","weather"),
    s("Windy Flags","🚩","weather"), s("Frost on Windows","🌨️","weather"),
    s("Morning Mist","🌁","weather"), s("Dramatic Clouds","🌤️","weather"),
    // Signs & Roads (25)
    s("Speed Limit 75+","🛑","signs"), s("Construction Zone","🚧","signs"),
    s("Detour Sign","↩️","signs"), s("No Passing Zone","⛔","signs"),
    s("Weigh Station","⚖️","signs"), s("Mile Marker ×0","🔢","signs"),
    s("Highway Interchange","🔄","signs"), s("Rest Area Sign","🛏️","signs"),
    s("Runaway Truck Ramp","🚛","signs"), s("Deer Crossing Sign","🦌","signs"),
    s("Falling Rock Sign","🪨","signs"), s("Chain Control Sign","⛓️","signs"),
    s("Low Clearance Sign","⬇️","signs"), s("Wrong Way Sign","🚫","signs"),
    s("Divided Highway Sign","↔️","signs"), s("Scenic Overlook Sign","🏞️","signs"),
    s("Historical Marker","📜","signs"), s("Adopt-a-Highway Sign","♻️","signs"),
    s("Road Narrows Sign","➡️","signs"), s("Bridge Ices Sign","🌉","signs"),
    s("Slippery When Wet","💧","signs"), s("No U-Turn Sign","🔃","signs"),
    s("Merging Traffic Sign","🔀","signs"), s("End Construction Sign","✅","signs"),
    s("State Highway Sign","🛣️","signs"),
]

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(data: try! encoder.encode(squares), encoding: .utf8)!)
