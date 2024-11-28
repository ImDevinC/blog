---
date: 2024-11-28
# description: How I made my home automation easily adoptable by family and friends
# image: ""
lastmod: 2024-11-28
showTableOfContents: false
# tags: ["",]
title: Making my home automation setup family friendly
type: "post"
---
# Home automation is great... for tech people
Like a lot of people recently, I've been diving into different pieces of home automation for my house. I see lots of really cool YouTube videos from people who post their very elaborate setups with tons of really cool features and that do insane things. I would like to get to that point eventually, where walking between rooms toggles lights, my blinds adjust based on my activities throughout the day, and who knows what else. One major piece that I feel is missing from these setups is making sure that the automations are friendly not only for the family living in the house (a lot of people do think about this), but also for when people come to visit our watch the house and we aren't home. That's what I need to solve for.

# A baseline, HomeAssistant
I knew that I had to be able to make sure things worked for friends, family, etc, but I also knew that doing that would require more up-front work to plan through the process appropriately and not have to do a bunch of work that I would have to redo later. After doing some research, it was very clear that the frontrunner for self-hosted home audition is [HomeAssistant](https://www.home-assistant.io/). Since I already had a kubernetes cluster, getting HomeAssistant up and running was pretty simple. I didn't do anything fancy yet, but I setup an account for my wife and I, installed the apps on our phone, and made sure that it could at least tell when we were home and when we weren't. Since I didn't have any other devices to add yet, this was a good point to figure out where to go next.

# Lights, Camera, Action!
One of my wife and I's biggest gripes is forgetting to turn off the lights at night, which means we debate about who gets out of bed to turn off the lights, which means I end up getting out of bed to turn off the lights. Since this was our biggest gripe, I figured this was a great place to start. I quickly figured out that making this friendly for everyone was going to be more of a challenge than I thought.
To start, here's a rough diagram of my house with lights and fans in my house.
![Home Layout](/images/home-automation-overview.png)

There's a few options available to tackle smart lighting, but I have a specific goal in mind to make it "friendly" as I mentioned. To start, let's look at our current layout:
- All fans are currently RF controlled and include lights. They have a single line that runs from the fan to the switch, meaning I can't control the fan and light separately at the switch, but have to use the remote.
- All my light switches are non-smart switches. I have two three way switches (one for each hallway).
- All of my existing lights are LED, but non-smart.

Taking this into account, and wanting to be as cost effective + future proof as possible, here's what I decided to do:
1. Install a z-wave hub (TODO: Z-WAVE HUB) to my HomeAssistant
    - I chose z-wave because it's widely supported by many devices and should be extensible. It also runs it's own mesh network so my entire house should be covered quite well.
1. Replace all light switches with [Inovelli LZW-30 Smart Switches](https://help.inovelli.com/en/articles/8453781-red-series-on-off-switch-manual)
1. Add a [Bond Bridge](https://bondhome.io/product/bond-bridge/) to relay RF communications from HomeAssistant to the different fans

I installed everything, making sure the switches all work as expected when paired with the existing remote. I then added each fan in the house to my Bond Bridge and added the [Bond integration](https://www.home-assistant.io/integrations/bond/) to HomeAssistant. This allowed me to control my devices directly through HomeAssistant, with separate controls for the fan and light.
I then added a custom blueprint for my z-wave switches that looks like this:
```yaml
> TODO: BLUEPRINT

```
This blueprint allows all of my switches to work in the following fashion:
1. Pressing the light switch up or down, as normal, will turn the light on or off
1. Double tapping the light switch up or down increases or decreases the fan speed
> [!NOTE] I did have to make one adjustment to the configuration on the actual light switch. For the double tapping to work correctly, I had to add a 3 second delay before taking action. This means that when I click the switch to toggle the light, it takes 3 seconds before the light actually turns on/off. My wife was ok with this, so I was ok with this.

Lastly, I added the [Google Assistant](https://www.home-assistant.io/integrations/google_assistant/) integration and configured it to work with the Google Hub's around my house. 

# Summary
This initial setup works great for my family. We can use voice controls to turn our lights and fans on and off, and if someone doesn't know that, the light switches all work like normal! The only thing we have to explain to people is how the fan toggle works, but it's simple enough that one time solves it. Since every fan works the same, it makes it easy as well. Eventually I'll 3d print a plate or something to go around the switch and provide directions for how to use it, but this works great for now.
I haven't figured out what my next step will be yet, but I'm thinking [RatGDO](https://paulwieland.github.io/ratgdo/) for the garage door. I'll update if I have to do fun things with it!
