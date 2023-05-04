	-- CS4400: Introduction to Database Systems: Wednesday, March 8, 2023
-- Flight Management Course Project Mechanics (v1.0) STARTING SHELL
-- Views, Functions & Stored Procedures

/* This is a standard preamble for most of our scripts.  The intent is to establish
a consistent environment for the database behavior. */
set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;
set @thisDatabase = 'flight_management';

use flight_management;
-- -----------------------------------------------------------------------------
-- stored procedures and views
-- -----------------------------------------------------------------------------
/* Standard Procedure: If one or more of the necessary conditions for a procedure to
be executed is false, then simply have the procedure halt execution without changing
the database state. Do NOT display any error messages, etc. */

-- [1] add_airplane()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airplane.  A new airplane must be sponsored
by an existing airline, and must have a unique tail number for that airline.
username.  An airplane must also have a non-zero seat capacity and speed. An airplane
might also have other factors depending on it's type, like skids or some number
of engines.  Finally, an airplane must have a database-wide unique location if
it will be used to carry passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_airplane;
delimiter //
create procedure add_airplane (in ip_airlineID varchar(50), in ip_tail_num varchar(50),
	in ip_seat_capacity integer, in ip_speed integer, in ip_locationID varchar(50),
    in ip_plane_type varchar(100), in ip_skids boolean, in ip_propellers integer,
    in ip_jet_engines integer)
sp_main: begin

INSERT INTO airplane (airlineID, tail_num, seat_capacity, speed, locationID, plane_type, skids, propellers, jet_engines)
VALUES (ip_airlineID, ip_tail_num, ip_seat_capacity, ip_speed, ip_locationID, ip_plane_type, ip_skids, ip_propellers, ip_jet_engines);

end //
delimiter ;

-- [2] add_airport()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airport.  A new airport must have a unique
identifier along with a database-wide unique location if it will be used to support
airplane takeoffs and landings.  An airport may have a longer, more descriptive
name.  An airport must also have a city and state designation. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_airport;
delimiter //
create procedure add_airport (in ip_airportID char(3), in ip_airport_name varchar(200),
    in ip_city varchar(100), in ip_state char(2), in ip_locationID varchar(50))
sp_main: begin
    
INSERT INTO airport (airportID, airport_name, city, state, locationID)
VALUES (ip_airportID, ip_airport_name, ip_city, ip_state, ip_locationID);

end //
delimiter ;

-- [3] add_person()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new person.  A new person must reference a unique
identifier along with a database-wide unique location used to determine where the
person is currently located: either at an airport, or on an airplane, at any given
time.  A person may have a first and last name as well.

Also, a person can hold a pilot role, a passenger role, or both roles.  As a pilot,
a person must have a tax identifier to receive pay, and an experience level.  Also,
a pilot might be assigned to a specific airplane as part of the flight crew.  As a
passenger, a person will have some amount of frequent flyer miles. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_person;
delimiter //
create procedure add_person (in ip_personID varchar(50), in ip_first_name varchar(100),
    in ip_last_name varchar(100), in ip_locationID varchar(50), in ip_taxID varchar(50),
    in ip_experience integer, in ip_flying_airline varchar(50), in ip_flying_tail varchar(50),
    in ip_miles integer)
sp_main: begin

INSERT INTO person (personID, first_name, last_name, locationID)
VALUES (ip_personID, ip_first_name, ip_last_name, ip_locationID);

IF ip_taxID IS NOT NULL THEN
	INSERT INTO pilot (personID, taxID, experience, flying_airline, flying_tail)
	VALUE (ip_personID, ip_taxID, ip_experience, ip_flying_airline, ip_flying_tail);
END IF;

IF ip_miles IS NOT NULL THEN
	INSERT INTO passenger (personID, miles)
	VALUES (ip_personID, ip_miles);
END IF;

end //
delimiter ;

-- [4] grant_pilot_license()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new pilot license.  The license must reference
a valid pilot, and must be a new/unique type of license for that pilot. */
-- -----------------------------------------------------------------------------
drop procedure if exists grant_pilot_license;
delimiter //
create procedure grant_pilot_license (in ip_personID varchar(50), in ip_license varchar(100))
sp_main: begin

IF EXISTS (SELECT personID FROM pilot WHERE ip_personID = personID) THEN
	INSERT INTO pilot_licenses (personID, license)
    VALUES (ip_personID, ip_license);
END IF;

end //
delimiter ;

-- [5] offer_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new flight.  The flight can be defined before
an airplane has been assigned for support, but it must have a valid route.  Once
an airplane has been assigned, we must also track where the airplane is along
the route, whether it is in flight or on the ground, and when the next action -
takeoff or landing - will occur. */
-- -----------------------------------------------------------------------------
drop procedure if exists offer_flight;
delimiter //
create procedure offer_flight (in ip_flightID varchar(50), in ip_routeID varchar(50),
    in ip_support_airline varchar(50), in ip_support_tail varchar(50), in ip_progress integer,
    in ip_airplane_status varchar(100), in ip_next_time time)
sp_main: begin

-- check if the route is valid
IF EXISTS (SELECT routeID FROM route WHERE routeID = ip_routeID) THEN
	-- check if airlineID and tail_num exist in airplane table
	IF EXISTS (SELECT * FROM airplane WHERE airlineID = ip_support_airline AND tail_num = ip_support_tail) THEN
		INSERT INTO flight (flightID, routeID, support_airline, support_tail, progress, airplane_status, next_time)
		VALUES (ip_flightID, ip_routeID, ip_support_airline, ip_support_tail, ip_progress, ip_airplane_status, ip_next_time);
	ELSE
		INSERT INTO flight (flightID, routeID, support_airline, support_tail, progress, airplane_status, next_time)
		VALUES (ip_flightID, ip_routeID, NULL, NULL, NULL, NULL, NULL);
	END IF;
END IF;

end //
delimiter ;

-- [6] purchase_ticket_and_seat()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new ticket.  The cost of the flight is optional
since it might have been a gift, purchased with frequent flyer miles, etc.  Each
flight must be tied to a valid person for a valid flight.  Also, we will make the
(hopefully simplifying) assumption that the departure airport for the ticket will
be the airport at which the traveler is currently located.  The ticket must also
explicitly list the destination airport, which can be an airport before the final
airport on the route.  Finally, the seat must be unoccupied. */
-- -----------------------------------------------------------------------------
drop procedure if exists purchase_ticket_and_seat;
delimiter //
create procedure purchase_ticket_and_seat (in ip_ticketID varchar(50), in ip_cost integer,
	in ip_carrier varchar(50), in ip_customer varchar(50), in ip_deplane_at char(3),
    in ip_seat_number varchar(50))
sp_main: begin

IF (EXISTS (SELECT * FROM person WHERE ip_customer = personID) 
		AND EXISTS (SELECT * FROM flight WHERE flightID = ip_carrier))
THEN
	IF NOT EXISTS (SELECT * FROM ticket_seats
    WHERE ticketID = ip_ticketID AND seat_number = ip_seat_number)
    THEN
        -- insert ticket only if the ticket is NOT FOUND
        IF NOT EXISTS (SELECT * FROM ticket WHERE ticketID = ip_ticketID) THEN
			INSERT INTO ticket (ticketID, cost, carrier, customer, deplane_at)
			VALUES (ip_ticketID, ip_cost, ip_carrier, ip_customer, ip_deplane_at);
        END IF;
        -- if the ticket exists, IF THE SEAT NOT FOUND
        -- insert seat
        INSERT INTO ticket_seats (ticketID, seat_number)
        VALUES (ip_ticketID, ip_seat_number);
	END IF;
END IF;

end //
delimiter ;

-- [7] add_update_leg()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new leg as specified.  However, if a leg from
the departure airport to the arrival airport already exists, then don't create a
new leg - instead, update the existence of the current leg while keeping the existing
identifier.  Also, all legs must be symmetric.  If a leg in the opposite direction
exists, then update the distance to ensure that it is equivalent.   */
-- -----------------------------------------------------------------------------
drop procedure if exists add_update_leg;
delimiter //
create procedure add_update_leg (in ip_legID varchar(50), in ip_distance integer,
    in ip_departure char(3), in ip_arrival char(3))
sp_main: begin

if exists (select arrival, departure from leg
where arrival = ip_arrival and departure = ip_departure) then
    update leg
    set distance = ip_distance
    where arrival = ip_arrival and departure = ip_departure;
else
	insert into leg (legID, distance, departure, arrival)
    values (ip_legID, ip_distance, ip_departure, ip_arrival);
end if;

if exists (select arrival, departure from leg
where arrival = ip_departure and departure = ip_arrival) then
	update leg
    set distance = ip_distance
    where arrival = ip_departure and departure = ip_arrival;
end if;

end; //
delimiter ;


-- [8] start_route()
-- -----------------------------------------------------------------------------
/* This stored procedure creates the first leg of a new route.  Routes in our
system must be created in the sequential order of the legs.  The first leg of
the route can be any valid leg. */
-- -----------------------------------------------------------------------------
drop procedure if exists start_route;
delimiter //
create procedure start_route (in ip_routeID varchar(50), in ip_legID varchar(50))
sp_main: begin

if ip_legID in (select legID from leg) then
	if not exists (select routeID, legID from route_path
	where routeID = ip_routeID and legID = ip_legID) then
		insert into route (routeID)
		values (ip_routeID);
        insert into route_path (routeID, legID, sequence)
		values (ip_routeID, ip_legID, 1);
	end if;
end if;

end; //
delimiter ;


-- [9] extend_route()
-- -----------------------------------------------------------------------------
/* This stored procedure adds another leg to the end of an existing route.  Routes
in our system must be created in the sequential order of the legs, and the route
must be contiguous: the departure airport of this leg must be the same as the
arrival airport of the previous leg. */
-- -----------------------------------------------------------------------------
drop procedure if exists extend_route;
delimiter //
create procedure extend_route (in ip_routeID varchar(50), in ip_legID varchar(50))
sp_main: begin

if ip_routeID in (select routeID from route) then
    
    if (select departure from leg where legID = ip_legID) in
    (select arrival from leg where legID in (select legID as prev_legID from route_path where routeID = ip_routeID))
    then
		
        set @incrementedSequence = 1 + (select max(sequence) from route_path where routeID = ip_routeID);
        insert into route_path (routeID, legID, sequence)
		values (ip_routeID, ip_legID, @incrementedSequence);
        
	end if;
end if;

end //
delimiter ;

-- [10] flight_landing()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight landing at the next airport
along its route.  The time for the flight should be moved one hour into the future
to allow for the flight to be checked, refueled, restocked, etc. for the next leg
of travel.  Also, the pilots of the flight should receive increased experience, and
the passengers should have their frequent flyer miles updated. */
-- -----------------------------------------------------------------------------
drop procedure if exists flight_landing;
delimiter //
create procedure flight_landing (in ip_flightID varchar(50))
sp_main: begin

if exists (select * from flight where airplane_status = 'in_flight' and flightID = ip_flightID) then
	update flight
    set airplane_status = 'on_ground', next_time = date_add(next_time, INTERVAL 1 hour)
    where flightID = ip_flightID;
    
    update pilot
    set experience = experience + 1
    where flying_tail = (select support_tail from flight where ip_flightID = flightID);
    
    update passenger as p
    
    set p.miles = p.miles + (select max(l.distance) from                               # Change this later!
    ((flight as f join route_path as r on f.routeID = r.routeID)
    join (leg as l) on l.legID = r.legID) where f.flightID = ip_flightID and l.legID = r.legID)
    
    where p.personID in
    (select personID from (person join ticket on customer = personID
    join flight on flightID = carrier)
    where carrier = ip_flightID);
    
end if;

end; //
delimiter ;

-- [11] flight_takeoff()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight taking off from its current
airport towards the next airport along its route.  The time for the next leg of
the flight must be calculated based on the distance and the speed of the airplane.
And we must also ensure that propeller driven planes have at least one pilot
assigned, while jets must have a minimum of two pilots. If the flight cannot take
off because of a pilot shortage, then the flight must be delayed for 30 minutes. */
-- -----------------------------------------------------------------------------
drop procedure if exists flight_takeoff;
delimiter //
create procedure flight_takeoff (in ip_flightID varchar(50))
sp_main: begin

if exists (select * from flight where airplane_status = 'on_ground' and flightID = ip_flightID) then
	
	if 'prop' in (select plane_type from airplane join flight on tail_num = support_tail where flightID = ip_flightID) and
	(select count(*) from (pilot as p) join (flight as f) on f.support_tail = p.flying_tail where flightID = ip_flightID) >= 1
	or 'jet' in (select plane_type from airplane join flight on tail_num = support_tail where flightID = ip_flightID) and
	(select count(*) from (pilot as p) join (flight as f) on f.support_tail = p.flying_tail where flightID = ip_flightID) >= 2 then
		
        update flight
        set progress = progress + 1
        where flightID = ip_flightID;
        
        set @dist =  (select distance from ((flight as f join route_path as r on f.routeID = r.routeID) join leg as l on r.legID = l.legID) where flightID = ip_flightID and f.progress = r.sequence);
        set @speed = (select speed from (flight join airplane on support_tail = tail_num) where flightID = ip_flightID);
        
        update flight
		set airplane_status = 'in_flight',
		next_time = date_add(next_time, INTERVAL @dist / @speed hour)
        where flightID = ip_flightID;
        
    else
		
        update flight
		set next_time = date_add(next_time, INTERVAL 30 minute)
		where flightID = ip_flightID;
        
	end if;
end if;

end; //
delimiter ;

-- [12] passengers_board()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting on a flight at
its current airport.  The passengers must be at the airport and hold a valid ticket
for the flight. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_board;
delimiter //
create procedure passengers_board (in ip_flightID varchar(50))
sp_main: begin

if exists (select * from flight where ip_flightID = flightID and airplane_status = 'on_ground') then
	update person
    set locationID = (select a.locationID from (flight as f join airplane as a on f.support_tail = a.tail_num) where f.flightID = ip_flightID)
    where personID in (select customer from ticket where ip_flightID = carrier);
end if;

end; //
delimiter ;

-- [13] passengers_disembark()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting off of a flight
at its current airport.  The passengers must be on that flight, and the flight must
be located at the destination airport as referenced by the ticket. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_disembark;
delimiter //
create procedure passengers_disembark (in ip_flightID varchar(50))
sp_main: begin

set @deplane_loc = NULL;
set @person_id = NULL;

select t.customer, t.deplane_at into @person_id, @deplane_loc from route_path rp
join flight f on rp.routeID = f.routeID
join leg l on l.legID = rp.legID
join ticket t on (t.carrier = f.flightID and t.deplane_at = l.arrival)
join passenger pa on pa.personID = t.customer
where f.flightID = ip_flightID
and f.progress = rp.sequence
limit 1;

update person p
set p.locationID = (select locationID from airport a where a.airportID = @deplane_loc)
where p.personID = @person_id;

end //
delimiter ;

-- [14] assign_pilot()
-- -----------------------------------------------------------------------------
/* This stored procedure assigns a pilot as part of the flight crew for a given
airplane.  The pilot being assigned must have a license for that type of airplane,
and must be at the same location as the flight.  Also, a pilot can only support
one flight (i.e. one airplane) at a time.  The pilot must be assigned to the flight
and have their location updated for the appropriate airplane. */
-- -----------------------------------------------------------------------------
drop procedure if exists assign_pilot;
delimiter //
create procedure assign_pilot (in ip_flightID varchar(50), ip_personID varchar(50))
sp_main: begin

set @airplane_type = NULL;
set @pilot_license = NULL;
set @assign_airline = NULL;
set @assign_tail = NULL;
set @airplane_loc = NULL;

(select a.plane_type, a.airlineID, a.tail_num 
into @airplane_type, @assign_airline, @assign_tail from flight f
join airplane a on a.airlineID = f.support_airline and a.tail_num = f.support_tail
where f.flightID = ip_flightID);

(select locationID into @airplane_loc from airplane
where airlineID = @assign_airline and tail_num = @assign_tail);

IF
	(@airplane_type
	=
	(select pl.license from person p
	join pilot pi on p.personID = pi.personID
	join pilot_licenses pl on p.personID = pl.personID
	where p.personID = ip_personID))
	AND
	((select p.locationID from person p
	where p.personID = ip_personID)
	IN
	(select a.locationID from flight f
	join route_path rp on f.routeID = rp.routeID
	join leg l on l.legID = rp.legID
	join airport a on a.airportID = l.departure
	where f.flightID = ip_flightID))
THEN
	update pilot pi
    set pi.flying_airline = @assign_airline, pi.flying_tail = @assign_tail
    where pi.personID = ip_personID;
    
    update person p
    set p.locationID = @airplane_loc
    where p.personID = ip_personID;
END IF;

end //
delimiter ;


-- [15] recycle_crew()
-- -----------------------------------------------------------------------------
/* This stored procedure releases the assignments for a given flight crew.  The
flight must have ended, and all passengers must have disembarked. */
-- -----------------------------------------------------------------------------
drop procedure if exists recycle_crew;
delimiter //
create procedure recycle_crew (in ip_flightID varchar(50))
sp_main: begin

if exists (select flightID from flight where ip_flightID = flightID)
and
(select airplane_status from flight where ip_flightID = flightID) = 'on_ground'
and 
not exists (select locationID from person as pe join passenger as pa on pe.personID = pa.personID where locationID in 
(select locationID from flight as f join airplane as a on f.support_airline = a.airlineID and f.support_tail = a.tail_num
where flightID = ip_flightID))
then
    set @temp_airline = NULL;
    set @temp_tail = NULL;
    
    set @new_loc = NULL;
    set @old_loc = NULL;

    select support_airline, support_tail INTO @temp_airline, @temp_tail from flight where flightID = ip_flightID;

    update pilot
    set flying_airline = null, flying_tail = null
    where flying_airline = @temp_airline and flying_tail = @temp_tail;
    
    select a.locationID, ai.locationID
	into @new_loc, @old_loc
	from airport a
	join leg l on a.airportID = l.arrival
	join route_path rp on rp.legID = l.legID
	join flight f on rp.routeID = f.routeID and rp.sequence = f.progress
	join airplane ai on f.support_tail = ai.tail_num
	where f.flightID = ip_flightID;
    
    update person
    set locationID = @new_loc
    where locationID = @old_loc;

end if;

end; //
delimiter ;

-- [16] retire_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a flight that has ended from the system.  The
flight must be on the ground, and either be at the start its route, or at the
end of its route.  */
-- -----------------------------------------------------------------------------
drop procedure if exists retire_flight;
delimiter //
create procedure retire_flight (in ip_flightID varchar(50))
sp_main: begin

IF EXISTS (select * from flight where flightID = ip_flightID) THEN

	IF (select airplane_status from flight where flightID = ip_flightID) = 'on_ground' AND
		(
        (select progress from flight where flightID = ip_flightID) = (select max(sequence) from route_path where routeID = (select routeID from flight where flightID = ip_flightID))
        OR
        (select progress from flight where flightID = ip_flightID) = 0
        )
	THEN
		DELETE FROM flight WHERE flightID = ip_flightID;
    END IF;
    
END IF;

end //
delimiter ;

-- [17] remove_passenger_role()
-- -----------------------------------------------------------------------------
/* This stored procedure removes the passenger role from person.  The passenger
must be on the ground at the time; and, if they are on a flight, then they must
disembark the flight at the current airport.  If the person had both a pilot role
and a passenger role, then the person and pilot role data should not be affected.
If the person only had a passenger role, then all associated person data must be
removed as well. */
-- -----------------------------------------------------------------------------
drop procedure if exists remove_passenger_role;
delimiter //
create procedure remove_passenger_role (in ip_personID varchar(50))
sp_main: begin

if exists (select personID from person where personID = ip_personID) then
	
    if (select locationID from person where personID = ip_personID) like 'plane_%'
    and (select airplane_status from
    (person as p join airplane as a on a.locationID = p.locationID
    join flight as f on f.support_tail = a.tail_num)
    where p.personID = ip_personID) = 'on_ground' 
    or (select locationID from person where personID = ip_personID) not like 'plane_%' then
		
        if ip_personID in (select personID from pilot) then
			delete from passenger where personID = ip_personID;
        else
			delete from passenger where personID = ip_personID;
            delete from person where personID = ip_personID;
		end if;
    end if;
end if;

end //
delimiter ;

-- [18] remove_pilot_role()
-- -----------------------------------------------------------------------------
/* This stored procedure removes the pilot role from person.  The pilot must not
be assigned to a flight; or, if they are assigned to a flight, then that flight
must either be at the start or end of its route.  If the person had both a pilot
role and a passenger role, then the person and passenger role data should not be
affected.  If the person only had a pilot role, then all associated person data
must be removed as well. */
-- -----------------------------------------------------------------------------
drop procedure if exists remove_pilot_role;
delimiter //
create procedure remove_pilot_role (in ip_personID varchar(50))
sp_main: begin
IF EXISTS (SELECT personID FROM pilot WHERE personID = ip_personID) THEN
        IF NOT EXISTS (
            SELECT flightID 
            FROM flight 
            JOIN route_path ON flight.routeID = route_path.routeID
            WHERE (flight.progress = 0 OR flight.progress = (SELECT MAX(route_path.sequence) FROM route_path WHERE route_path.routeID = flight.routeID))
              AND EXISTS (SELECT * FROM pilot WHERE personID = ip_personID AND flying_tail = flight.support_tail)
        ) THEN
			SET foreign_key_checks = 0;
            DELETE FROM pilot WHERE personID = ip_personID;
            DELETE FROM pilot_licenses WHERE personID = ip_personID;
            IF NOT EXISTS (SELECT * FROM passenger WHERE personID = ip_personID) THEN
                DELETE FROM person WHERE personID = ip_personID;
            END IF;
            SET foreign_key_checks = 1;
        END IF;
    END IF;
end //
delimiter ;

-- [19] flights_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where flights that are currently airborne are located. */
-- -----------------------------------------------------------------------------
create or replace view flights_in_the_air (departing_from, arriving_at, num_flights,
	flight_list, earliest_arrival, latest_arrival, airplane_list) as
SELECT leg.departure AS departure_airport,
       leg.arrival AS arrival_airport,
       COUNT(*) AS num_flights,
       GROUP_CONCAT(DISTINCT flight.flightID ORDER BY flight.flightID) AS flight_list,
       flight.next_time AS earliest_arrival,
       flight.next_time AS latest_arrival,
       GROUP_CONCAT(DISTINCT airplane.locationID ORDER BY airplane.locationID) AS airplane_list
FROM flight
JOIN route_path ON flight.routeID = route_path.routeID
JOIN leg ON route_path.legID = leg.legID
JOIN airplane ON flight.support_airline = airplane.airlineID AND flight.support_tail = airplane.tail_num
WHERE flight.airplane_status = 'in_flight' AND route_path.sequence = flight.progress
GROUP BY leg.departure, leg.arrival, flight.next_time;

-- [20] flights_on_the_ground()
-- -----------------------------------------------------------------------------
/* This view describes where flights that are currently on the ground are located. */
-- -----------------------------------------------------------------------------
create or replace view flights_on_the_ground (departing_from, num_flights,
	flight_list, earliest_arrival, latest_arrival, airplane_list) as 
SELECT leg.departure AS departing_from,
	   COUNT(*) AS num_flights,
       GROUP_CONCAT(DISTINCT flight.flightID ORDER BY flight.flightID) AS flight_list,
       flight.next_time AS earliest_arrival,
       flight.next_time AS latest_arrival,
       GROUP_CONCAT(DISTINCT airplane.locationID ORDER BY airplane.locationID) AS airplane_list
FROM flight
JOIN route_path ON flight.routeID = route_path.routeID
JOIN leg ON route_path.legID = leg.legID
JOIN airplane ON flight.support_airline = airplane.airlineID AND flight.support_tail = airplane.tail_num
WHERE flight.airplane_status = 'on_ground' AND route_path.sequence - 1 = flight.progress
GROUP BY leg.departure, flight.next_time;

-- [21] people_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently airborne are located. */
-- -----------------------------------------------------------------------------
create or replace view people_in_the_air (departing_from, arriving_at, num_airplanes,
	airplane_list, flight_list, earliest_arrival, latest_arrival, num_pilots,
	num_passengers, joint_pilots_passengers, person_list) as
SELECT leg.departure AS departing_from, 
	   leg.arrival AS arriving_at,
       COUNT(DISTINCT flight.flightID) as num_airplanes,
	   airplane.locationID AS airplane_list, 
	   GROUP_CONCAT(DISTINCT flight.flightID ORDER BY flight.flightID) AS flights, 
	   flight.next_time AS earliest_arrival,
	   flight.next_time AS latest_arrival,
	   COUNT(DISTINCT CASE WHEN person.personID IN (SELECT personID FROM pilot) THEN person.personID END) AS num_pilots, 
       COUNT(DISTINCT CASE WHEN person.personID IN (SELECT personID FROM passenger) THEN person.personID END) AS num_passengers, 
	   COUNT(DISTINCT person.personID) AS joint_pilots_passengers, 
	   GROUP_CONCAT(DISTINCT person.personID ORDER BY person.personID) AS person_list
FROM flight 
JOIN route_path ON flight.routeID = route_path.routeID 
JOIN leg ON route_path.legID = leg.legID 
JOIN airplane ON flight.support_airline = airplane.airlineID AND flight.support_tail = airplane.tail_num 
JOIN ticket ON flight.flightID = ticket.carrier 
JOIN person ON person.locationID = airplane.locationID
WHERE flight.airplane_status = 'in_flight' AND route_path.sequence = flight.progress
GROUP BY leg.departure, leg.arrival, airplane.locationID, flight.next_time;

-- [22] people_on_the_ground()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently on the ground are located. */
-- -----------------------------------------------------------------------------
create or replace view people_on_the_ground (departing_from, airport, airport_name,
	city, state, num_pilots, num_passengers, joint_pilots_passengers, person_list) as
SELECT DISTINCT leg.departure AS departing_airport,
       airport.locationID AS airport, 
       airport.airport_name AS airport_name,
       airport.city AS city,
       airport.state AS state,
       COUNT(DISTINCT CASE WHEN person.personID IN (SELECT personID FROM pilot) THEN person.personID END) AS num_pilots, 
       COUNT(DISTINCT CASE WHEN person.personID IN (SELECT personID FROM passenger) THEN person.personID END) AS num_passengers, 
       COUNT(DISTINCT person.personID) AS joint_pilots_passengers, 
       GROUP_CONCAT(DISTINCT person.personID ORDER BY person.personID) AS person_list
FROM flight 
JOIN route_path ON flight.routeID = route_path.routeID 
JOIN leg ON route_path.legID = leg.legID 
JOIN airplane ON flight.support_airline = airplane.airlineID AND flight.support_tail = airplane.tail_num
JOIN ticket ON flight.flightID = ticket.carrier 
JOIN airport ON airport.airportID = leg.departure
JOIN person ON person.locationID = airport.locationID AND person.locationID in (select locationID from airport)
WHERE flight.airplane_status = 'on_ground'
GROUP BY leg.departure, airport.locationID, airport.airport_name, airport.city, airport.state
UNION
SELECT airportID AS departing_airport,
       airport.locationID AS airport, 
       airport.airport_name AS airport_name,
       airport.city AS city,
       airport.state AS state,
       COUNT(DISTINCT CASE WHEN person.personID IN (SELECT personID FROM pilot) THEN person.personID END) AS num_pilots, 
       COUNT(DISTINCT CASE WHEN person.personID IN (SELECT personID FROM passenger) THEN person.personID END) AS num_passengers, 
       COUNT(DISTINCT person.personID) AS joint_pilots_passengers, 
       GROUP_CONCAT(DISTINCT person.personID ORDER BY person.personID) AS people
FROM person
JOIN airport ON airport.locationID = person.locationID
GROUP BY airport.airportID, airport.locationID, airport.airport_name, airport.city, airport.state;

-- [23] route_summary()
-- -----------------------------------------------------------------------------
/* This view describes how the routes are being utilized by different flights. */
-- -----------------------------------------------------------------------------
create or replace view route_summary (route, num_legs, leg_sequence, route_length,
	num_flights, flight_list, airport_sequence) as
SELECT
  route.routeID,
  COUNT(DISTINCT leg.legID) AS num_legs,
  GROUP_CONCAT(DISTINCT leg.legID ORDER BY route_path.sequence) AS leg_sequence,
  temp.total_distance AS route_length,
  COUNT(DISTINCT flight.flightID) AS num_flights,
  GROUP_CONCAT(DISTINCT flight.flightID ORDER BY flight.flightID) AS flight_list,
  GROUP_CONCAT(DISTINCT CONCAT(leg.departure, ' -> ', leg.arrival) ORDER BY route_path.sequence SEPARATOR ', ') AS airport_sequence
FROM route
JOIN route_path ON route_path.routeID = route.routeID
JOIN leg ON leg.legID = route_path.legID
JOIN airport ON airport.airportID IN (leg.departure, leg.arrival)
LEFT JOIN flight ON flight.routeID = route.routeID
JOIN (SELECT 
		route.routeID,
		SUM(leg.distance) AS total_distance
	  FROM route 
      JOIN route_path ON route.routeID = route_path.routeID
	  JOIN leg ON route_path.legID = leg.legID
	  GROUP BY route.routeID) AS temp on temp.routeID = route.routeID
GROUP BY route.routeID;

-- [24] alternative_airports()
-- -----------------------------------------------------------------------------
/* This view displays airports that share the same city and state. */
-- -----------------------------------------------------------------------------
create or replace view alternative_airports (city, state, num_airports,
	airport_code_list, airport_name_list) as
SELECT 
  a.city, 
  a.state,
  COUNT(*) AS num_airports_shared,
  GROUP_CONCAT(DISTINCT a.airportID ORDER BY a.airportID) AS airport_codes_shared,
  GROUP_CONCAT(DISTINCT a.airport_name ORDER BY a.airportID) AS airport_names_shared
FROM airport AS a
JOIN airport AS b ON a.city = b.city AND a.state = b.state AND a.airportID != b.airportID
GROUP BY a.city, a.state
HAVING COUNT(*) > 1;

-- [25] simulation_cycle()
-- -----------------------------------------------------------------------------
/* This stored procedure executes the next step in the simulation cycle.  The flight
with the smallest next time in chronological order must be identified and selected.
If multiple flights have the same time, then flights that are landing should be
preferred over flights that are taking off.  Similarly, flights with the lowest
identifier in alphabetical order should also be preferred.

If an airplane is in flight and waiting to land, then the flight should be allowed
to land, passengers allowed to disembark, and the time advanced by one hour until
the next takeoff to allow for preparations.

If an airplane is on the ground and waiting to takeoff, then the passengers should
be allowed to board, and the time should be advanced to represent when the airplane
will land at its next location based on the leg distance and airplane speed.

If an airplane is on the ground and has reached the end of its route, then the
flight crew should be recycled to allow rest, and the flight itself should be
retired from the system. */
-- -----------------------------------------------------------------------------
drop procedure if exists simulation_cycle;
delimiter //
create procedure simulation_cycle ()
sp_main: begin

set @land_flightID = NULL;
set @land_time = NULL;
set @current_progress = NULL;

select flightID, next_time, progress into @land_flightID, @land_time, @current_progress from flight where flightID in
(select flightID from flight 
where next_time = (select min(next_time) from flight)
order by flightID) order by airplane_status limit 1;

if exists (
select earliest_arrival, latest_arrival from flights_in_the_air 
where FIND_IN_SET(@land_flightID, flight_list) 
and @land_time between earliest_arrival and latest_arrival
)
then
	call flight_landing(@land_flightID);
	call passengers_disembark(@land_flightID);
    
    
    
end if;

if exists (
select earliest_arrival, latest_arrival from flights_on_the_ground 
where FIND_IN_SET(@land_flightID, flight_list) 
and @land_time between earliest_arrival and latest_arrival)
then
	call flight_takeoff(@land_flightID);
   	call passengers_board(@land_flightID);
end if;

if (
    select max(sequence) from route_path rp 
	join flight f on f.routeID = rp.routeID
	where f.flightID = @land_flightID
    ) = @current_progress then
		call recycle_crew(@land_flightID);
        call retire_flight(@land_flightID);
    end if;

end //
delimiter ;