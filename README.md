# jorgehub

An experimental flatpack remoted designed to prototype Flathub's transition to OCI. Someone promised me a magical land of shared storage and composefs, I guess we'll find out. 😄

- Flatpak packing skills for automation
- Serves the remote from github pages to clients, pushes the flatpak to [the registry](https://github.com/users/castrojo/packages/container/package/jorgehub%2Fghostty)
- Chunka and zstd:chunked enabled for partial pulls
- We need data when this lands in OS bootc images so we might as well get going.

This potentially unlocks all container registries and git forges as Flatpak hosts in a format supported by flatpak. This is a prototype and not a replacement or substitute for Flathub's official process, this is designed to test the package format changes.

## Add this remote

    flatpak remote-add --if-not-exists jorgehub oci+https://castrojo.github.io/jorgehub

## Install an app

    flatpak install jorgehub com.mitchellh.ghostty
