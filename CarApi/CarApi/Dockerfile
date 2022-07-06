#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:3.1 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:3.1 AS build
WORKDIR /src
COPY ["CarApi/CarApi.csproj", "CarApi/"]
RUN dotnet restore "CarApi/CarApi.csproj"
COPY . .
WORKDIR "/src/CarApi"
RUN dotnet build "CarApi.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "CarApi.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "CarApi.dll"]