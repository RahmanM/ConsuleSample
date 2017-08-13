# ConsuleSample
Sample configuration and .net code for Consul set up

Steps:
- Set the IPs if needed
- Run the Dev-Cluster.bat in the server machine
- Run the dev-client.bat in the client machine
- In this stage client and server should be joined

Using the following # code to test adding / removing servies etc:

```c#

    public class ConsulRegisterer
    {

        public ConsulRegisterer(string url)
        {
            Url = url;
        }

        public ConsulRegisterer() {}

        public string Url { get; }

        public async Task<string> ReadKeyValues(string key)
        {
            using (var client = GetClient())
            {
                var getPair = await client.KV.Get(key);
                return Encoding.UTF8.GetString(getPair.Response.Value, 0, getPair.Response.Value.Length);
            }
        }

        private ConsulClient GetClient()
        {
            if(!string.IsNullOrWhiteSpace(Url))
            {
                return new ConsulClient(a => new ConsulClientConfiguration { Address = new Uri(Url) });
            }

            return new ConsulClient();
        }
        
        // Add key values
        public async Task AddKeyValues(string key, string value)
        {
            using (var client = GetClient())
            {

                var putPair = new KVPair(key)
                {
                    Value = Encoding.UTF8.GetBytes(value)
                };

                await client.KV.Put(putPair);
            }
        }
        
        // Register a service with health check
        public async Task<bool> RegisterService(ServiceDetails serviceDetails)
        {
            var localIP = LocalIPAddress().ToString();

            using (var client = GetClient())
            {
                var id = $"{localIP}.{serviceDetails.ServiceName}";

                var registration = new AgentServiceRegistration
                {
                    Name = serviceDetails.ServiceName,
                    Port = serviceDetails.Port.GetValueOrDefault(),
                    Address = serviceDetails.Address ?? localIP,
                    Tags = serviceDetails.Tags,
                    ID = id,
                    Check =
                    new AgentCheckRegistration
                    {
                        Name = "PortIsAliveCheck",
                        TCP = $"{localIP}:{serviceDetails.Port}",
                        Notes = $"Runs a TCP check to verify {id} on {localIP}:{serviceDetails.Port} is alive.",
                        Timeout = TimeSpan.FromMilliseconds(1000),
                        Interval = TimeSpan.FromMilliseconds(1000),
                        DeregisterCriticalServiceAfter = TimeSpan.FromMilliseconds(5000)
                        
                    }
                };

                await client.Agent.ServiceRegister(registration);
            }

            return true;
        }

        public static IPAddress LocalIPAddress()
        {
            if (!NetworkInterface.GetIsNetworkAvailable())
                throw new ApplicationException("No IPV4 Network is available");
            var host = Dns.GetHostEntry(Dns.GetHostName());
            return host
                .AddressList
                .FirstOrDefault(ip => ip.AddressFamily == AddressFamily.InterNetwork);
        }

        // unregister a service
        public async Task UnRegisterService(string endPointName)
        {
            using (var client = GetClient())
            {
                await client.Agent.ServiceDeregister(endPointName);
            }
        }

        public async Task<ServiceDetails> ReadServiceDetails(string serviceName)
        {
            using (var client = GetClient())
            {
                var services = await client.Agent.Services();
                foreach (var element in services.Response.Keys)
                {
                    if(services.Response[element].Service == serviceName)
                    {
                        return new ServiceDetails()
                        {
                            ServiceName = services.Response[element].Service,
                            Address = services.Response[element].Address,
                            Port = services.Response[element].Port,
                            Tags = services.Response[element].Tags
                        };
                    }
                }
            }

            return null;
        }

        public static async Task<HealthCheck> DoHealthCheck(string endpointName)
        {
            using (var client = new ConsulClient())
            {
                var checks = await client.Health.Checks(endpointName);
                foreach (var element in checks.Response.ToList())
                {
                    return element;
                }
            }

            return null;
        }

        /// <summary>
        /// NOTE: reading from the catalog enables to read from all nodes
        /// </summary>
        /// <param name="serviceName">Name of the service to get details for</param>
        public async Task<ServiceDetails> ReadServiceDetailsFromCatalog(string serviceName)
        {
            using (var client = GetClient())
            {
                var services = await client.Catalog.Service(serviceName);
                foreach (var service in services.Response)
                {
                    if (service.ServiceName == serviceName)
                    {
                        return new ServiceDetails()
                        {
                            ServiceName = service.ServiceName,
                            Address = service.ServiceAddress,
                            Port = service.ServicePort,
                            Tags = service.ServiceTags
                        };
                    }
                }
            }

            return null;
        }

        public async Task<bool> RegisterServiceUsingCatalog(ServiceDetails serviceDetails)
        {
            using (var client = GetClient())
            {
                await client.Catalog.Register(new CatalogRegistration()
                {
                    Service = new AgentService()
                    {
                        Address = serviceDetails.Address,
                        Port = serviceDetails.Port.GetValueOrDefault(),
                        Tags = serviceDetails.Tags,
                        Service = serviceDetails.ServiceName            
                    },
                    Node = serviceDetails.Node,
                    Address = serviceDetails.Address
                });
            }

            return true;
        }


    }
    
     public class ServiceDetails
    {
        public string ServiceName { get;  set; }
        public int? Port { get; set; }
        public string Address { get; set; }
        public string[] Tags { get; set; }
        public string Node { get; set; }
    }
    
    
    ```
