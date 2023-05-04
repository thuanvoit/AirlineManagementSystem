from flask import (
    Flask,
    flash,
    get_flashed_messages,
    redirect,
    url_for,
    render_template,
    request,
)
from flaskext.mysql import MySQL
import os
import re

username = ""
password = ""
cycle_count = 0

filename = "db_credentials.txt"
if not os.path.exists(filename):
    with open(filename, "w") as f:
        f.write("#delete this line and fill with your database username\n")
        f.write(
            "#delete this line and fill with your database password then re-run the app"
        )

with open(filename, "r") as f:
    username = f.readline().strip()
    password = f.readline().strip()

app = Flask(__name__)
app.config["TEMPLATES_AUTO_RELOAD"] = True
app.secret_key = "secret_key"
mysql = MySQL()
# MySQL configurations
app.config["MYSQL_DATABASE_USER"] = username
app.config["MYSQL_DATABASE_PASSWORD"] = password
app.config["MYSQL_DATABASE_DB"] = "flight_management"
app.config["MYSQL_DATABASE_HOST"] = "localhost"
mysql.init_app(app)
connection = mysql.connect()

@app.route("/")
@app.route("/index")
@app.route("/main")
def main():
    error_msg = ""
    error_msg_cat = "error"
    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)
    return render_template(
        "index.html",
    )


def fetch_data(column_names, table_name):
    """
    Use this method to fetch columns from a table
    column_names: can be multiple column, seperate by comma

    e.g. fetch_data('airlineID', 'airline')

    """
    cursor = connection.cursor()
    cursor.execute(f"SELECT {column_names} FROM {table_name}")
    data = cursor.fetchall()
    cursor.close()
    clean_data = [item[0] for item in data]
    return clean_data


def run_procedure(proc_name, proc_inputs):
    """
    Use this to call procedure.
    proc_name: name of procedure
    proc_inputs: a tuple of all inputs of that procedure

    e.g. run_procedure('add_airport', (airportID, airport_name, city, state, locationID) )

    """
    error = None
    proc_inputs = format_for_procedure(proc_inputs)
    print(proc_inputs)
    cursor = connection.cursor()

    try:
        cursor.execute("SET foreign_key_checks = 0")
        cursor.callproc(proc_name, proc_inputs)
        cursor.execute("SET foreign_key_checks = 1")
    except Exception as e:
        error = str(e)
    finally:
        connection.commit()
        cursor.close()
        return error


def format_for_procedure(param_list: tuple):
    lst = list(param_list)
    for i, element in enumerate(lst):
        if not element or element == "":
            lst[i] = None
    return lst


def custom_query(query):
    cursor = connection.cursor()
    cursor.execute(query)
    data = cursor.fetchall()
    cursor.close()
    clean_data = [item[0] for item in data]
    return clean_data


def flash_error_msg(error_msg, error_msg_cat):
    get_flashed_messages()
    if str(error_msg).strip():
        if app.debug:
            print(f"DEBUG: error_msg='{error_msg}'")
        flash(str(error_msg).strip(), str(error_msg_cat).strip())
        return redirect(url_for("main"))


def check_regex(text, pattern):
    if not re.match(pattern, text):
        return False
    return True


@app.route("/add_airplane", methods=["GET", "POST"])
def add_airplane():
    error_msg = ""
    error_msg_cat = "error"
    airlineID_list = fetch_data("airlineID", "airline")
    locationID_list = fetch_data("locationID", "location")

    new_locationID_list = list()
    for loc in locationID_list:
        if "plane" in loc:
            new_locationID_list.append(loc)

    if request.method == "POST":
        airlineID = request.form["airportID"]
        plane_type = request.form["plane_type"]
        tail_num = request.form["tail_num"]

        skids = request.form["skids"]
        skids = int(0 if skids == "" else skids)

        seat_capacity = request.form["seat_capacity"]
        seat_capacity = int(0 if seat_capacity == "" else seat_capacity)

        propellers = request.form["propeller"]
        propellers = int(0 if propellers == "" else propellers)

        speed = request.form["speed"]
        speed = int(0 if speed == "" else speed)

        jet_engines = request.form["jet_engines"]
        jet_engines = int(0 if jet_engines == "" else jet_engines)

        locationID = request.form["location_id"]

        if seat_capacity == "" or int(seat_capacity) <= 0:
            error_msg = "Must have seating!"
        elif speed == "" or int(speed) <= 0:
            error_msg = "Must have speed!"
        elif len(tail_num) != 6:
            error_msg = "Must provide 6-char long tail number!"
        elif plane_type == "jet" and (
            int(jet_engines) <= 0 or int(propellers) != 0 or int(skids) != 0
        ):
            error_msg = "Wrong characteristics for a jet plane"
        elif plane_type == "prop" and (
            int(propellers) <= 0 or int(skids) < 0 or int(jet_engines) != 0
        ):
            error_msg = "Wrong characteristics for a propeller-based plane"
        else:
            if plane_type == "jet":
                propellers = None
                skids = None
            elif plane_type == "prop":
                jet_engines = None

            error = run_procedure(
                "add_airplane",
                (
                    airlineID,
                    tail_num,
                    seat_capacity,
                    speed,
                    locationID,
                    plane_type,
                    skids,
                    propellers,
                    jet_engines,
                ),
            )
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"{airlineID} airplane with tail number {tail_num} added successfully"

    flash_error_msg(error_msg, error_msg_cat)
    return render_template(
        "add_airplane.html",
        airlineID_list=airlineID_list,
        locationID_list=new_locationID_list,
    )


@app.route("/add_airport", methods=["GET", "POST"])
def add_airport():
    error_msg = ""
    error_msg_cat = "error"
    locationID_list = fetch_data("locationID", "location")

    new_locationID_list = list()
    for loc in locationID_list:
        if "port" in loc:
            new_locationID_list.append(loc)
    
    new_locationID_list.append('no_location')

    if request.method == "POST":
        airportID = request.form["airportID"]
        airport_name = request.form["airport_name"]
        city = request.form["city"]
        state = request.form["state"]
        locationID = request.form["location_id"]

        if len(airportID) != 3:
            error_msg = "Must provide 3-char long airportID!"
        elif len(state) != 2:
            error_msg = "Must provide 2-char long state ID!"

        if (locationID == 'no_location'):
            locationID = None

        
        error = run_procedure(
            "add_airport",
            (
                airportID.upper(),
                airport_name.capitalize(),
                city.capitalize(),
                state.upper(),
                locationID,
            ),
        )
        if error:
            error_msg = "SQL Procedure Error: " + error
        else:
            error_msg_cat = "ok"
            error_msg = f"Airport {airportID} added successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "add_airport.html",
        locationID_list=new_locationID_list,
    )


@app.route("/add_person", methods=["GET", "POST"])
def add_person():
    error_msg = ""
    error_msg_cat = "error"
    locationID_list = fetch_data("locationID", "location")

    airlineID_list = fetch_data("airlineID", "airline")
    tail_list = fetch_data("tail_num", "airplane")

    if request.method == "POST":
        
        personID = request.form["personID"]
        first_name = request.form["first_name"]
        last_name = request.form["last_name"]
        locationID = request.form["location_id"]
        taxID = request.form["taxID"]
        flying_airline = request.form["airline"]
        flying_tail = request.form["tail"]

        miles = request.form["miles"]
        miles = None if miles == "" else int(miles)
        print(miles)

        experience = request.form["experience"]
        experience = None if experience == "" else int(experience)

        if first_name == "" or last_name == "":
            error_msg = "Must have valid name!"
        elif personID == "":
            error_msg = "Must have person ID!"
        elif personID in fetch_data("personID", "person"):
            error_msg = "personID must be unique!"
        elif locationID == "":
            error_msg = "Must have location"
        elif taxID != "" and not experience:
            error_msg = "Pilots must have a listed experience!"
        elif taxID and not check_regex(taxID, r"^\d{3}-\d{2}-\d{4}$"):
            error_msg = "TaxID doesn't match pattern xxx-xx-xxxx"
        elif taxID == "" and (
            flying_airline != "no_airline" or flying_tail != "no_tail"
        ):
            error_msg = (
                "Can only include the airline details for a pilot with a tax ID!"
            )
        elif experience and experience < 0:
            error_msg = "Experience cannot be negative"
        elif miles and miles < 0:
            error_msg = "Frequent flyer miles cannot be negative"
        elif flying_airline == "no_airline" and flying_tail != "no_tail":
            error_msg = "Must have an airline to have a tail"
        elif flying_airline != "no_airline" and flying_tail == "no_tail":
            error_msg = "Must have a tail to have a airline"
        else:
            if flying_airline == "no_airline":
                flying_airline = None
            if flying_tail == "no_tail":
                flying_tail = None

            error = run_procedure(
                "add_person",
                (
                    personID,
                    first_name,
                    last_name,
                    locationID,
                    taxID,
                    experience,
                    flying_airline,
                    flying_tail,
                    miles,
                ),
            )
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"Person {personID} added successfully"

    flash_error_msg(error_msg, error_msg_cat)
    return render_template(
        "add_person.html",
        locationID_list=locationID_list,
        airlineID_list=airlineID_list,
        tail_list=tail_list,
    )


@app.route("/grant_pilot_license", methods=["GET", "POST"])
def grant_pilot_license():
    error_msg = ""
    error_msg_cat = "error"

    person_list = fetch_data("personID", "pilot")
    license_list = custom_query(f"select license from pilot_licenses group by license")

    if request.method == "POST":
        personID = request.form["personID"]
        license_type = request.form["license_type"]
        custom_license_type = request.form["custom_license_type"]
        
        error = ''
        
        if (license_type == 'custom'):
            if (custom_license_type == ''):
                error = 'invalid_custom'
            else:
                error = run_procedure("grant_pilot_license", (personID, custom_license_type))
        else:
            error = run_procedure("grant_pilot_license", (personID, custom_license_type))
        
        if error:
            if error == 'invalid_custom':
                error_msg = f"License type cannot be null!"
            else:
                error_msg = f"{personID} already had a {license_type} {custom_license_type} license"
        else:
            error_msg_cat = "ok"
            error_msg = f"{license_type.capitalize()} license granted to {personID} successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template("grant_pilot_license.html", person_list=person_list, license_list = license_list)


@app.route("/offer_flight", methods=["GET", "POST"])
def offer_flight():
    error_msg = ""
    error_msg_cat = "error"
    route_list = fetch_data("routeID", "route")
    airplane_list = []

    cursor = connection.cursor()
    cursor.execute("select airlineID, tail_num from airplane")
    data = cursor.fetchall()
    cursor.close()
    for i, item in enumerate(data):
        airplane_list.append(f"{item[0]} - {item[1]}")

    if request.method == "POST":
        flightID = request.form["flightID"]
        routeID = request.form["routeID"]
        support_airline, support_tail = request.form["support_airline"].split(" - ", 1)
        progress = request.form["progress"]
        airplane_status = request.form["airplane_status"]
        next_time = request.form["next_time"]
        route_sequences = custom_query(f"select sequence from route_path where routeID = '{routeID}'")

        if flightID == "":
            error_msg = "Must have a flight ID!"
        elif not check_regex(flightID, r"^[A-Z]{2}\_\d{3,}$"):
            error_msg = "FlightID invalid!"
        elif not progress or int(progress) < 0:
            error_msg = "A progress must not be null or negative"
        elif int(progress) == 0 and airplane_status == 'in_flight':
            error_msg = "A flight at progress 0 must be on the ground"
        elif int(progress) > max(route_sequences):
            error_msg = f"Route {routeID} has only {max(route_sequences)} sequences"
        else:
            error = run_procedure(
                "offer_flight",
                (
                    flightID,
                    routeID,
                    support_airline,
                    support_tail,
                    progress,
                    airplane_status,
                    next_time,
                ),
            )
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"Flight {flightID} offered on {routeID} route successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "offer_flight.html", route_list=route_list, airplane_list=airplane_list
    )


@app.route("/purchase_ticket_and_seat", methods=["GET", "POST"])
def purchase_ticket_and_seat():
    error_msg = ""
    error_msg_cat = "error"

    deplane_list = fetch_data("airportID", "airport")
    carrier_list = fetch_data("flightID", "flight")
    person_list = fetch_data("personID", "person")

    if request.method == "POST":
        ticketID = request.form["ticketID"]
        cost = request.form["cost"]
        carrier = request.form["carrier"]
        customer = request.form["customer"]
        deplane = request.form["deplane"]
        seat_num = request.form["seat_num"]
        ticket_pattern = '_'.join(ticketID.split('_')[:2])
        check_exist_seat = custom_query(f"SELECT seat_number FROM ticket_seats WHERE ticketID like '{ticket_pattern}%' AND seat_number = '{seat_num}'")
        
        if ticketID == "":
            error_msg = "You must enter a ticket ID!"
        elif not check_regex(ticketID, r"^tkt\_[a-z]{2}\_\d{1,}$"):
            error_msg = "ticketID invalid!"
        elif cost and int(cost) < 0:
            error_msg = "Invalid cost!"
        elif seat_num == "":
            error_msg = "You must provide a seat number!"
        elif not check_regex(seat_num, r"^\d*[A-Z]$"):
            error_msg = "Invalid seat number!"
        elif deplane == "" or len(deplane) != 3:
            error_msg = "Invalid deplane airport code!"
        elif check_exist_seat:
            error_msg = "Seat is already occupied!"
        else:
            error = run_procedure(
                "purchase_ticket_and_seat",
                (ticketID, cost, carrier, customer, deplane, seat_num),
            )
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"Ticket {ticketID} for seat {seat_num} purchased successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "purchase_ticket_and_seat.html",
        carrier_list=carrier_list,
        person_list=person_list,
        deplane_list=deplane_list,
    )


@app.route("/add_update_leg", methods=["GET", "POST"])
def add_update_leg():
    error_msg = ""
    error_msg_cat = "error"
    airport_list = fetch_data("airportID", "airport")
    if request.method == "POST":
        legID = request.form["legID"]
        distance = request.form["distance"]
        departure = request.form["departure"]
        arrival = request.form["arrival"]

        if legID == "":
            error_msg = "You must provide a leg ID!"
        elif not check_regex(legID, r"^leg_\d{1,}$"):
            error_msg = "Invalid legID format"
        elif distance == "" or int(distance) <= 0:
            error_msg = "Invalid distance!"
        elif departure == arrival:
            error_msg = "Departure and Arrival cannot be the same!"
        else:
            error = run_procedure(
                "add_update_leg", (legID, distance, departure, arrival)
            )
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"{legID} updated successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "add_update_leg.html",
        airport_list=airport_list,
    )


@app.route("/start_route", methods=["GET", "POST"])
def start_route():
    error_msg = ""
    error_msg_cat = "error"
    leg_list = fetch_data("legID", "leg")

    if request.method == "POST":
        routeID = request.form["routeID"]
        legID = request.form["legID"]

        if routeID == "":
            error_msg = "You must provide a route ID!"
        elif legID == "":
            error_msg = "You must provide a leg ID!"
        else:
            error = run_procedure("start_route", (routeID, legID))
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"{routeID} route started successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "start_route.html",
        leg_list=leg_list,
    )


@app.route("/extend_route", methods=["GET", "POST"])
def extend_route():
    error_msg = ""
    error_msg_cat = "error"
    leg_list = fetch_data("legID", "leg")
    route_list = fetch_data("routeID", "route")

    if request.method == "POST":
        routeID = request.form["routeID"]
        legID = request.form["legID"]
        prev_arrival = custom_query(f"select arrival from leg where legID = (select legID from route_path where routeID = '{routeID}' and sequence = (select max(sequence) from route_path where routeID = '{routeID}'))")
        next_departure = custom_query(f"select departure from leg where legID = '{legID}'")

        if routeID == "":
            error_msg = "You must provide a route ID!"
        elif legID == "":
            error_msg = "You must provide a leg ID!"
        elif prev_arrival != next_departure:
            error_msg = f"Next departure airport ({next_departure[0]}) not the same as last arrival airport ({prev_arrival[0]}) of the route {routeID}"
        else:
            error = run_procedure("extend_route", (routeID, legID))
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"{legID} added to route {routeID} successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "extend_route.html",
        leg_list=leg_list,
        route_list=route_list,
    )


@app.route("/flight_landing", methods=["GET", "POST"])
def flight_landing():
    error_msg = ""
    error_msg_cat = "error"
    flight_list = fetch_data("flightID", "flight")

    if request.method == "POST":
        flightID = request.form["flightID"]
        flight_status = custom_query(f"select airplane_status from flight where flightID = '{flightID}'")
        if flight_status[0] == 'on_ground':
            error_msg = f"Flight {flightID} is already on the ground"
        elif not flight_status[0]:
            error_msg = f"Flight {flightID} is not operating"
        else:
            error = run_procedure("flight_landing", (flightID,))
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"Flight {flightID} landed successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template("flight_landing.html", flight_list=flight_list)


@app.route("/flight_takeoff", methods=["GET", "POST"])
def flight_takeoff():
    error_msg = ""
    error_msg_cat = "error"
    flight_list = fetch_data("flightID", "flight")

    if request.method == "POST":
        flightID = request.form["flightID"]
        plane_type = custom_query(f"select plane_type from airplane join flight on tail_num = support_tail where flightID = '{flightID}'")
     
        # we need to fix this in our script
        num_pilots = custom_query(f"select count(*) from (pilot as p) join (flight as f) on f.support_tail = p.flying_tail where flightID = '{flightID}'")
        flight_status = custom_query(f"select airplane_status from flight where flightID = '{flightID}'")

        if flight_status[0] == 'in_flight':
            error_msg = f"Flight {flightID} is already in the air"
        elif not flight_status[0]:
            error_msg = f"Flight {flightID} is not operating"
        else:
            error = run_procedure("flight_takeoff", (flightID,))
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                if int(num_pilots[0]) < 1 and plane_type[0] == 'prop':
                    error_msg = f"Propeller plane must have at least one pilot assigned. Flight {flightID} delayed 30 minutes"
                elif int(num_pilots[0]) < 2 and plane_type[0] == 'jet':
                    error_msg = f"Jet plane must have at least two pilot assigned. Flight {flightID} delayed 30 minutes"
                else:
                    error_msg_cat = "ok"
                    error_msg = f"Flight {flightID} took off successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template("flight_takeoff.html", flight_list=flight_list)


@app.route("/passengers_board", methods=["GET", "POST"])
def passengers_board():
    error_msg = ""
    error_msg_cat = "error"
    flight_list = fetch_data("flightID", "flight")

    if request.method == "POST":
        flightID = request.form["flightID"]
        flight_status = custom_query(f"select airplane_status from flight where flightID = '{flightID}'")

        if flight_status[0] == 'in_flight':
            error_msg = "Cannot board a flight still in the air"
        else:
            error = run_procedure("passengers_board", (flightID,))
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"All passengers boarded flight {flightID} successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template("passengers_board.html", flight_list=flight_list)


@app.route("/passengers_disembark", methods=["GET", "POST"])
def passengers_disembark():
    error_msg = ""
    error_msg_cat = "error"
    flight_list = fetch_data("flightID", "flight")

    if request.method == "POST":
        flightID = request.form["flightID"]
        flight_status = custom_query(f"select airplane_status from flight where flightID = '{flightID}'")

        if flight_status[0] == 'in_flight':
            error_msg = "Cannot board a flight still in the air"
        else:
            error = run_procedure("passengers_disembark", (flightID,))    
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"All passengers disembarked flight {flightID} successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template("passengers_disembark.html", flight_list=flight_list)


@app.route("/assign_pilot", methods=["GET", "POST"])
def assign_pilot():
    error_msg = ""
    error_msg_cat = "error"
    person_list = fetch_data("personID", "pilot")
    flight_list = fetch_data("flightID", "flight")

    if request.method == "POST":
        personID = request.form["personID"]
        flightID = request.form["flightID"]
        plane_type = custom_query(f"select plane_type from airplane join flight on tail_num = support_tail where flightID = '{flightID}'")
        if not plane_type: # flightID is not supported by any airplane, so plane type is null
            plane_type = '[None]'
        if not plane_type[0]: # no plane type can be assumed to be of testing type
            plane_type[0] = 'testing'
        pilot_licenses = custom_query(f"select license from pilot_licenses where personID = '{personID}'")
        pilot_flight = custom_query(f"select flying_tail from pilot where personID = '{personID}'")
        flight_location = custom_query(f"select a.locationID from flight f join route_path rp on f.routeID = rp.routeID join leg l on l.legID = rp.legID join airport a on a.airportID = l.departure where f.flightID = '{flightID}' and (f.progress = rp.sequence or (f.progress = 0 and rp.sequence = 1))")
        if not flight_location: # flightID is not supported by any airplane, so flight_location is null
            flight_location = ['unsupported flight']
        flight_status = custom_query(f"select airplane_status from flight where flightID = '{flightID}'")
        pilot_location = custom_query(f"select p.locationID from person p where p.personID = '{personID}'")
        print("Planetype: ")
        print(plane_type)
        print(pilot_location)
        print(flight_location)

        if pilot_flight[0]:
            error_msg = f"Pilot {personID} is already assigned to another flight"
        elif plane_type[0] not in pilot_licenses:
            error_msg = f"Pilot {personID} does not have {plane_type[0]} license for flight {flightID}"
        elif flight_status[0] and flight_status[0] != 'on_ground':
            error_msg = f"Cannot assign a pilot to a flight not on the ground"
        elif flight_location[0] != pilot_location[0]:
            error_msg = f"Pilot {personID} is not at the same location as flight {flightID}"
        else:
            error = run_procedure("assign_pilot", (flightID, personID))
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"{personID} assigned as pilot successfully"
    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "assign_pilot.html",
        person_list=person_list,
        flight_list=flight_list,
    )


@app.route("/recycle_crew", methods=["GET", "POST"])
def recycle_crew():
    error_msg = ""
    error_msg_cat = "error"
    flight_list = fetch_data("flightID", "flight")

    if request.method == "POST":
        flightID = request.form["flightID"]
        check_passengers_disembarked = custom_query(f"select locationID from person as pe join passenger as pa on pe.personID = pa.personID where locationID in (select locationID from flight as f join airplane as a on f.support_airline = a.airlineID and f.support_tail = a.tail_num where flightID = '{flightID}')")
        flight_status = custom_query(f"select airplane_status from flight where flightID = '{flightID}'")
        flight_progress = custom_query(f"select progress from flight where flightID = '{flightID}'")
        route_max = custom_query(f"select max(sequence) from route_path where routeID = (select routeID from flight where flightID = '{flightID}')")
        # flight isn't assigned with any airplane (DL_3410, UN_717) will have the below variables null
        if not flight_progress[0]:
            flight_progress = ['0']

        if check_passengers_disembarked:
            error_msg = f"Not all passengers have disembarked flight {flightID}"
        elif flight_status[0] and flight_status[0] != 'on_ground':
            error_msg = "Cannot recycle crew of flight in the air"
        elif int(route_max[0]) != int(flight_progress[0]) and int(flight_progress[0]) != 0:
            error_msg = "Cannot recycle crew of flight not ended"
        elif not flight_status[0] or not flight_progress[0]:
            error_msg = f"Flight {flightID} is not operating"
        else:
            error = run_procedure("recycle_crew", (flightID,))
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"Recycled crew on flight {flightID} successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "recycle_crew.html",
        flight_list=flight_list,
    )


@app.route("/retire_flight", methods=["GET", "POST"])
def retire_flight():
    error_msg = ""
    error_msg_cat = "error"
    flight_list = fetch_data("flightID", "flight")

    if request.method == "POST":
        flightID = request.form["flightID"]
        flight_status = custom_query(f"select airplane_status from flight where flightID = '{flightID}'")
        flight_progress = custom_query(f"select progress from flight where flightID = '{flightID}'")
        route_max = custom_query(f"select max(sequence) from route_path where routeID = (select routeID from flight where flightID = '{flightID}')")
        # flight isn't assigned with any airplane (DL_3410, UN_717) will have the below variables null
        if not flight_progress[0]:
            flight_progress = ['0']

        if flight_status[0] and flight_status[0] != 'on_ground':
            error_msg = "Cannot retire flight in the air"
        elif int(route_max[0]) != int(flight_progress[0]) and int(flight_progress[0]) != 0:
            error_msg = "Cannot retire flight not at the start or the end of its route"
        elif not flight_status[0] or not flight_progress[0]:
            error_msg = f"Flight {flightID} is not operating"
        else:
            error = run_procedure("retire_flight", (flightID,))
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"Flight {flightID} retired successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "retire_flight.html",
        flight_list=flight_list,
    )


@app.route("/remove_passenger_role", methods=["GET", "POST"])
def remove_passenger_role():
    error_msg = ""
    error_msg_cat = "error"
    person_list = fetch_data("personID", "passenger")

    if request.method == "POST":
        personID = request.form["personID"]
        error = run_procedure("remove_passenger_role", (personID,))
        if error:
            error_msg = "SQL Procedure Error: " + error
        else:
            error_msg_cat = "ok"
            error_msg = f"Passenger {personID} removed successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "remove_passenger_role.html",
        person_list=person_list,
    )


@app.route("/remove_pilot_role", methods=["GET", "POST"])
def remove_pilot_role():
    error_msg = ""
    error_msg_cat = "error"
    person_list = fetch_data("personID", "pilot")

    if request.method == "POST":
        personID = request.form["personID"]
        check_assignment = custom_query(
                f"select flying_tail from pilot where personID = '{personID}'"
            )

        if check_assignment[0]:
            error_msg = "You cannot remove a pilot currently assigned to a flight!"
        else:
            error = run_procedure("remove_pilot_role", (personID,))
            if error:
                error_msg = "SQL Procedure Error: " + error
            else:
                error_msg_cat = "ok"
                error_msg = f"Pilot {personID} removed successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)
    return render_template(
        "remove_pilot_role.html",
        person_list=person_list,
    )


@app.route("/flights_in_the_air", methods=["GET", "POST"])
def flights_in_the_air():
    error_msg = ""
    error_msg_cat = "error"

    cursor = connection.cursor()
    cursor.execute("select * from flights_in_the_air")
    data = cursor.fetchall()
    cursor.close()

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "flights_in_the_air.html",
        data=data,
    )


@app.route("/flights_on_the_ground", methods=["GET", "POST"])
def flights_on_the_ground():
    error_msg = ""
    error_msg_cat = "error"

    cursor = connection.cursor()
    cursor.execute("select * from flights_on_the_ground")
    data = cursor.fetchall()
    cursor.close()

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "flights_on_the_ground.html",
        data=data,
    )


@app.route("/people_in_the_air", methods=["GET", "POST"])
def people_in_the_air():
    error_msg = ""
    error_msg_cat = "error"

    cursor = connection.cursor()
    cursor.execute("select * from people_in_the_air")
    data = cursor.fetchall()
    cursor.close()

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "people_in_the_air.html",
        data=data,
    )


@app.route("/people_on_the_ground", methods=["GET", "POST"])
def people_on_the_ground():
    error_msg = ""
    error_msg_cat = "error"

    cursor = connection.cursor()
    cursor.execute("select * from people_on_the_ground")
    data = cursor.fetchall()
    cursor.close()

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "people_on_the_ground.html",
        data=data,
    )


@app.route("/route_summary", methods=["GET", "POST"])
def route_summary():
    error_msg = ""
    error_msg_cat = "error"

    cursor = connection.cursor()
    cursor.execute("select * from route_summary")
    data = cursor.fetchall()
    cursor.close()

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "route_summary.html",
        data=data,
    )


@app.route("/alternative_airports", methods=["GET", "POST"])
def alternative_airports():
    error_msg = ""
    error_msg_cat = "error"

    cursor = connection.cursor()
    cursor.execute("select * from alternative_airports")
    data = cursor.fetchall()
    cursor.close()

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)

    return render_template(
        "alternative_airports.html",
        data=data,
    )

@app.route("/simulation_cycle", methods=["GET", "POST"])
def simulation_cycle():
    global cycle_count
    error_msg = ""
    error_msg_cat = "error"

    table_name = "flight"

    if request.method == "POST" and 'select_table' in request.form:
        table_name = request.form["select_table"]

    cursor = connection.cursor()
    cursor.execute("show tables")
    table_list = cursor.fetchall()
    table_list = [item[0] for item in table_list]

    cursor.execute(f"select * from {table_name}")
    data = cursor.fetchall()

    cursor.execute(f"show columns from {table_name}")
    columns = cursor.fetchall()
    columns = [item[0] for item in columns]
    cursor.close()

    # INSERT CODE BEFORE flash_error
    if request.method == "POST" and 'sim' in request.form:
        print(request.form)
        print('run sim')
        error = run_procedure("simulation_cycle", ())
        if error:
            error_msg = "SQL Procedure Error: " + error
        else:
            error_msg_cat = "ok"
            cycle_count += 1
            error_msg = f"Cycle {cycle_count} ran successfully"

    # INSERT CODE BEFORE flash_error
    flash_error_msg(error_msg, error_msg_cat)
    return render_template(
        "simulation_cycle.html",
        table_list=table_list,
        data=data,
        columns=columns,
        table_name=table_name,
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
    