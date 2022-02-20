For Task 5 our team has made separate robots for seeding and weeding, with each of them navigating on a different arena. We've also used custom start positions as they were allowed.

A few points to note about our submission:

1. Our _gripper_ broke down irreparably, hence we couldn't record a video of the plants being weeded, however we have shown the arm-movement and line following in detail.

2. Both the robots are able to move simultaneously however, we have uploaded videos of separate movement as our college was shut and we couldn't get a place to put down both arenas together. Other than that our seeding video shows 3/4 of the seeds being sown.

3. Coming to the algorithm, the flowchart of the whole program can be found in the attached `"Task5 Diagrams.pdf"`

4. The code for FWClientRobotB is the same as A, the only difference is instead of weeding, in the seeding function, we give angles to a servo in increments of `60 degrees`. I've mentioned it here as it isn't in the flowchart

5. We weren't able to get a way to receive the `"event_msg"` with `"event_id" => 6` sent from the Server in the Client, however the message is still being sent. We've implemented stopping the robot with a different method.
