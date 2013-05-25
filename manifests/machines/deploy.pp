# A machine to deploy within the environment
class machines::deploy inherits machines::base {
    # Install Jenkins
    include jenkins
    ufw::allow { 'allow-jenkins-from-jumpbox':
        port => 8080,
        ip   => 'any',
        from => $::hosts['jumpbox-1.management']['ip']
    }
}
