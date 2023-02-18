# Ruby on Rails developer profile

Let's start with the target audience of Ruby on Rails, which we can infer from the [web site](https://rubyonrails.org/).

> Learn just what you need to get started, then keep leveling up as you go. Ruby on Rails scales from HELLO WORLD to IPO.

It is fair to conclude from this that a typical Ruby on Rails developer meets some or all of the following characteristics:

 * member of a small team
 * business subject matter experts
 * knowledgeable of, or recently introduced to, the Ruby programming language

# Docker developer profile

To illustrate the target audience of Rails Dockerfiles, I'm going to succinctly state some rather basic background information that is necessary to confidently make changes to the Rails 7.1 generated Dockerfiles:

> Most [official Ruby dockerhub images](https://hub.docker.com/_/ruby)
> are based on Debian [bullseye](https://www.debian.org/releases/bullseye/),
> which provides a [large number of packages](https://packages.debian.org/stable/)
> that you can install.
> Simply find the packages that you need and add them to the `apt-get install` line
> in the relevant [build stage](https://docs.docker.com/build/building/multi-stage/).

# Intersection of the prior two groups

Based on my experiences at [fly.io](https://fly.io/), the overlap between the members of the first group and the set of people that understand the paragraph in the second section isn't as large as you might think or hope.

The purpose of the Dockerfile generator is to help bridge that gap.

A usage scenario is that a team is formed.  They create an application.  When they started they were provided with a Dockerfile that is capable of deploying a HELLO WORLD application.  After several months of effort they are ready to deploy.  Undoubtedly they made at least one change that will require a modification to the Dockerfile, and find that they don't have the skills necessary to to make that change.

Make no mistake about it, we are talking about intelligent, motivated people.  Just ones that may have never used a Debian Linux operating system before.

# Value Proposition

The goal is, whenever possible, have the following command bring the Dockerfile and associated files up to date with the current application:

```cmd
bin/rails generate dockerfile
```

Being able to rerun this command means that each invocation can focus on installing only what is necessary or selected to run this application, and not install other things that may (or may not) be useful later.

While a laudable goad, it clearly is unattainable.  So a second goal is to make solutions to common problems be via one liners that can be shared via FAQs, Stack Overflow, Discourse, Discord, Slack or whatever.

Some examples can be found in [Fly.io's FAQ](https://fly.io/docs/rails/getting-started/dockerfiles/).  The hope is that this generator becomes widely adopted and similar pages adapted to different target audiences pop up everywhere.  That makers of gems with special deployment needs produce pull requests to make it easier for Rails applications that make use of their gems to be deployed.

Of course some will use this only as a starting point and make their own changes.  We welcome that.  Advanced users who need to run it again can use techniques like `git add --patch` to select which changes they want to keep.  Really advanced users will contribute back changes to this gem so that they can avoid the need to patch in the future.

# Futures

This can go in many directions.  Some thoughts.

* While the number of popular gems with special installation requirements is finite, it may make sense to evolve a plug-in architecture where gems take ownership of their own requirements.  [Kuby](https://getkuby.io/) has a plugin system, so we should too.

* [Create React App](https://reactjs.org/docs/create-a-new-react-app.html) has (had? I can't really be sure if this project is going to revive) an interesting approach.  Configuration files are invisible until you eject.  I'd love to see a [future where Dockerfiles were invisible and generated on deploy](https://fly.io/ruby-dispatch/dockerfile-less-deploys/).

* CLIs are wonderful, but many have become spoiled by point and click dashboards.  Changing the problem from "anything you can put into a Dockerfile" to a set of options that can be expressed in a YAML file should enable such dashboards to be created.
